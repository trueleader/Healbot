local linenum=1
local HealBot_CheckBuffs = {}
local HealBot_Tooltip_DirtyLines={}
local xUnit=nil
local xGUID=nil
local xButton=nil
local hbGameTooltip = CreateFrame("GameTooltip", "hbGameTooltip", nil, "GameTooltipTemplate")
local _
local hbCommands = { [strlower(HEALBOT_DISABLED_TARGET)]=true,
                     [strlower(HEALBOT_ASSIST)]=true, 
                     [strlower(HEALBOT_FOCUS)]=true,
                     [strlower(HEALBOT_MENU)]=true,
                     [strlower(HEALBOT_HBMENU)]=true,
                     [strlower(HEALBOT_STOP)]=true,
                     [strlower(HEALBOT_TELL)]=true,
                    }  
local HealBot_Tooltip_luVars={}
HealBot_Tooltip_luVars["uGroup"]=false

function HealBot_Tooltip_Clear_CheckBuffs()
    for x,_ in pairs(HealBot_CheckBuffs) do
        HealBot_CheckBuffs[x]=nil;
    end
end

function HealBot_Tooltip_CheckBuffs(buff)
    HealBot_CheckBuffs[buff]=true;
end

local function HealBot_Tooltip_ReturnMinsSecs(s)
    local mins=floor(s/60)
    local secs=floor(s-(mins*60))
  --  mins=mins+1
    if secs<10 then secs="0"..secs end
    return mins,secs
end

local function HealBot_Tooltip_readNumber(n)
    if n>99999999 then
        n=tostring(HealBot_Comm_round(n/1000000,0)).."M"
    elseif n>9999999 then
        n=tostring(HealBot_Comm_round(n/1000000,1)).."M"
    elseif n>999999 then
        n=tostring(HealBot_Comm_round(n/1000000,2)).."M"
    elseif n>99999 then
        n=tostring(HealBot_Comm_round(n/1000,0)).."K"
    elseif n>9999 then
        n=tostring(HealBot_Comm_round(n/1000,1)).."K"
    else
        n=tostring(n)
    end
    return n
end

local function HealBot_Tooltip_SpellPattern(button, click)
    local sPattern=nil
    if IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown() then
        if click=="Left" then
            sPattern=HEALBOT_TOGGLE_ENABLED
        elseif click=="Right" then
            if HealBot_Panel_RetMyHealTarget(button.unit) then
                sPattern=HEALBOT_WORDS_REMOVEFROM.." "..HEALBOT_OPTIONS_MYTARGET
            else
                sPattern=HEALBOT_WORDS_ADDTO.." "..HEALBOT_OPTIONS_MYTARGET
            end
            --HealBot_Panel_ToggelHealTarget(self.unit)
        elseif not UnitIsUnit(button.unit, "player") and click=="Middle" then
            sPattern=HEALBOT_WORDS_ADDTO.." "..HEALBOT_PANEL_BLACKLIST
        end
    else    
        local hbCombos = HealBot_Config_Spells.EnabledKeyCombo
        if HealBot_Data["TIPTYPE"]=="Disabled" then
            hbCombos = HealBot_Config_Spells.DisabledKeyCombo
        elseif HealBot_Data["TIPTYPE"]=="Enemy" then
            hbCombos = HealBot_Config_Spells.EnemyKeyCombo
        end
        if not hbCombos then return nil end
        local x = click;
        if IsShiftKeyDown() then 
            if IsAltKeyDown() then 
                x = "Alt-Shift"..x
            elseif IsControlKeyDown() then 
                x = "Ctrl-Shift"..x
            else
                x = "Shift"..x
            end
        elseif IsAltKeyDown() then 
            if IsControlKeyDown() then 
                 x = "Alt-Ctrl"..x
            else
                x = "Alt"..x
            end
        elseif IsControlKeyDown() then 
            x = "Ctrl"..x 
        end
        x=x..HealBot_Config.CurrentSpec
        sPattern=hbCombos[x]
    end
    return sPattern
end

local function HealBot_Tooltip_GetHealSpell(button,sName)
    if not sName or not HealBot_Spell_Names[sName] then
        if sName then
            local s = GetItemSpell(sName)
            if not s then
                return nil, 1,0.5
            else
                if HealBot_Data["PGUID"]~=button.guid then
                    if IsItemInRange(sName,button.unit) then
                        return sName, 0, 1
                    else
                        return sName, 1,0.5
                    end
                else
                    return sName, 0, 1
                end
            end
        else
            return nil, 1,0.5
        end
    end

    if HealBot_UnitInRange(button.unit, sName, false)<1 then
        return sName, 1,0.5
    end
 
    return sName, 0, 1
end

local function HealBot_Tooltip_setspellName(button, spellName)
    local validSpellName=spellName
    local spellAR,spellAG=1,1
    if spellName then
        spellAR,spellAG=0,1
        if not hbCommands[strlower(spellName)] then
            local mIdx=GetMacroIndexByName(spellName)
            if mIdx==0 then 
                validSpellName, spellAR, spellAG = HealBot_Tooltip_GetHealSpell(button,spellName) 
                if validSpellName then
                    local z, x, _ = GetSpellCooldown(spellName);
                    if x and x>1 then 
                        z = HealBot_Comm_round(x-(GetTime()-z),3)
                        local u=HEALBOT_TOOLTIP_SECS
                        if HealBot_Globals.Tooltip_ShowCD then
                            z = HealBot_Comm_round(z,1)
                            if z>=10 then
                                if z>59 then
                                    z = ceil(z/60)
                                    u=HEALBOT_TOOLTIP_MINS
                                else
                                    z = HealBot_Comm_round(z,0)
                                end
                            elseif ceil(z)==z then
                                u=".0"..u
                            end                            
                            validSpellName=validSpellName..HEALBOT_TOOLTIP_CD..z..u 
                            if z>0 then spellAR,spellAG=1,0.5 end
                        elseif z>0.101 then
                            spellAR,spellAG=1,0.5
                        end
                    end
                end
            else
                spellAR,spellAG=0.5,1
            end
        end
    end
    return validSpellName, spellAR, spellAG
end

local function HealBot_Tooltip_SetLineLeft(Text,R,G,B,lNo,a)
    if lNo>40 then return end
    local txtL = _G["HealBot_TooltipTextL" .. lNo]
    txtL:SetTextColor(R,G,B,a)
    txtL:SetText(Text)
    txtL:Show()
    HealBot_Tooltip_DirtyLines[lNo]=true
end

local function HealBot_Tooltip_SetLineRight(Text,R,G,B,lNo,a)
    if lNo>40 then return end
    local txtR = _G["HealBot_TooltipTextR" .. lNo]
    txtR:SetTextColor(R,G,B,a)
    txtR:SetText(Text)
    txtR:Show()
    HealBot_Tooltip_DirtyLines[lNo]=true
end

local function HealBot_Tooltip_SetLine(lNo,lText,lR,lG,lB,la,rText,rR,rG,rB,ra)
    if rText then
        if HealBot_Globals.UseGameTooltip then
            GameTooltip:AddDoubleLine(lText,rText,lR,lG,lB,rR,rG,rB)
        else
            HealBot_Tooltip_SetLineLeft(lText,lR,lG,lB,lNo,la)
            HealBot_Tooltip_SetLineRight(rText,rR,rG,rB,lNo,ra)
        end
    else
        if HealBot_Globals.UseGameTooltip then
            GameTooltip:AddLine(lText,lR,lG,lB)
        else
            HealBot_Tooltip_SetLineLeft(lText,lR,lG,lB,lNo,la)
        end
    end
end

local HealBot_Tooltip_Power = 9
local function HealBot_Tooltip_SpellInfo(spellName)
    if HealBot_Spell_IDs[spellName] then
        if HealBot_Spell_IDs[spellName].Mana>0 then
            linenum=linenum+1
            if HealBot_Spell_IDs[spellName].Mana<HealBot_Tooltip_Power then
                HealBot_Tooltip_SetLine(linenum,HEALBOT_WORDS_CAST..": "..HealBot_Spell_IDs[spellName].CastTime.." "..HEALBOT_WORDS_SEC..".",0.8,0.8,0.8,1,"Power: "..HealBot_Spell_IDs[spellName].Mana,0.4,0.4,1,1)
            else
                HealBot_Tooltip_SetLine(linenum,HEALBOT_WORDS_CAST..": "..HealBot_Spell_IDs[spellName].CastTime.." "..HEALBOT_WORDS_SEC..".",0.8,0.8,0.8,1,"Mana: "..HealBot_Spell_IDs[spellName].Mana,0.4,0.4,1,1)
            end
        end
    end
end

local function HealBot_Tooltip_SpellSummary(spellName)
    local ret_val = "  "
    if HealBot_Spell_IDs[spellName] then
        if HealBot_Spell_IDs[spellName].Mana<HealBot_Tooltip_Power then
            ret_val = " -  "..HealBot_Spell_IDs[spellName].Mana.." Power"
        else
            ret_val = " -  "..HealBot_Spell_IDs[spellName].Mana.." Mana"
        end
    end
    if strlen(ret_val)<5 then ret_val = " - "..spellName; end
    return ret_val;
end

local function HealBot_Tooltip_CheckForInstant(unit,spellName)
    if spellName and HealBot_Spell_IDs[spellName] then
        if HealBot_Spell_IDs[spellName].HoT then
            if HealBot_HasUnitBuff(HealBot_Spell_IDs[spellName].HoT,unit,"player") then return false end;  
            return true;
        end
    end
    return false;
end

local function HealBot_Tooltip_Show()
    if HealBot_Globals.UseGameTooltip then
        GameTooltip:Show();
    else
        local height = 20 
        local width = 0
        for x = 1, linenum do
            local txtL = _G["HealBot_TooltipTextL" .. x]
            local txtR = _G["HealBot_TooltipTextR" .. x]
            height = height + txtL:GetHeight() + 2
            if (txtL:GetWidth() + txtR:GetWidth() + 25 > width) then
                width = txtL:GetWidth() + txtR:GetWidth() + 25
            end
        end
        HealBot_Tooltip:SetWidth(width)
        HealBot_Tooltip:SetHeight(height)
        HealBot_Tooltip:Show();
    end
end

local UnitBuffIcons=nil
local UnitDebuffIcons=nil
local function HealBot_ToolTip_ShowHoT(unit)
    if HealBot_Globals.Tooltip_ShowHoT then
        local hbHoTline1=true
        UnitBuffIcons=HealBot_retHoTdetails(unit)
        if UnitBuffIcons then
            for name,_ in pairs(UnitBuffIcons) do
                if linenum<44 and UnitBuffIcons[name].current then
                    if UnitBuffIcons[name].unitCaster then
                        local ttCaster=UnitName(UnitBuffIcons[name].unitCaster)
                        if ttCaster then
                            local ttHoTd=nil
                            if hbHoTline1 then
                                hbHoTline1=nil
                                linenum=linenum+1
                            end
                            linenum=linenum+1
                            if UnitBuffIcons[name].expirationTime and UnitBuffIcons[name].expirationTime>0 then
                                ttHoTd=floor(UnitBuffIcons[name].expirationTime-GetTime())
                            end
                            local ttHoTc=UnitBuffIcons[name].count or 0
                            local ttHoTright=nil
                            if ttHoTd and ttHoTd>60 then
                                local ttHoTdt=floor(ttHoTd/60)
                                if ttHoTdt>120 then
                                    ttHoTd=nil
                                else
                                    ttHoTd=ttHoTd - (ttHoTdt*60)
                                    if ttHoTd<10 then ttHoTd="0"..ttHoTd end
                                    ttHoTd=ttHoTdt.."m "..ttHoTd
                                end
                            end
                            if ttHoTd then 
                                ttHoTright=" "..HEALBOT_OPTIONS_HOTTEXTDURATION..": "..ttHoTd.."s   " 
                            else
                                ttHoTright=" "
                            end
                            if ttHoTc>0 then 
                                ttHoTright=ttHoTright..HEALBOT_OPTIONS_HOTTEXTCOUNT..": "..ttHoTc.."   " 
                            else
                                ttHoTright=ttHoTright.."   " 
                            end
                            if ttHoTright then 
                                HealBot_Tooltip_SetLine(linenum,"   "..ttCaster.." "..strlower(HEALBOT_WORDS_CAST).." "..name.." ",0.4,1,1,1,ttHoTright,0.7,1,0.7,1)
                            else
                                HealBot_Tooltip_SetLine(linenum,"   "..ttCaster.." "..strlower(HEALBOT_WORDS_CAST).." "..name.." ",0.4,1,1,1)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function HealBot_ToolTip_SetTooltipPos()
    xButton=HealBot_Unit_Button[HealBot_Data["TIPUNIT"]] or HealBot_Enemy_Button[HealBot_Data["TIPUNIT"]] or HealBot_Pet_Button[HealBot_Data["TIPUNIT"]]
    if xButton then
        local g = _G["f"..xButton.frame.."_HealBot_Action"]
        local top = g:GetTop();
        local x, y = GetCursorPosition();
        if HealBot_Globals.UseGameTooltip then
            if Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]>1 then
                x=x/UIParent:GetScale();
                y=y/UIParent:GetScale();
                if Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]==2 then
                    GameTooltip:SetOwner(g, "ANCHOR_LEFT", 0, 0-(top-(y-50)))
                elseif Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]==3 then
                    GameTooltip:SetOwner(g, "ANCHOR_RIGHT", 0, 0-(top-(y-50)))
                elseif Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]==4 then
                   GameTooltip:SetOwner(g, "ANCHOR_TOP")
                elseif Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]==5 then
                   GameTooltip:SetOwner(g, "ANCHOR_BOTTOM")
                else
                    GameTooltip:SetOwner(g, "ANCHOR_NONE")
                    GameTooltip:SetPoint("TOPLEFT","WorldFrame","BOTTOMLEFT",x+25,y-20);
                end
            else
                GameTooltip:SetOwner(g, "ANCHOR_NONE")
                GameTooltip_SetDefaultAnchor(GameTooltip, hbGameTooltip)
            end
        else
            HealBot_Tooltip:ClearAllPoints();
            if Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]>1 then
                x=x/UIParent:GetScale();
                y=y/UIParent:GetScale();
                if Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]==2 then
                    HealBot_Tooltip:SetPoint("TOPRIGHT",g,"TOPLEFT",0,0-(top-(y+35)));
                elseif Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]==3 then
                    HealBot_Tooltip:SetPoint("TOPLEFT",g,"TOPRIGHT",0,0-(top-(y+35)));
                elseif Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]==4 then
                    HealBot_Tooltip:SetPoint("BOTTOM",g,"TOP",0,0);
                elseif Healbot_Config_Skins.Frame[Healbot_Config_Skins.Current_Skin][xButton.frame]["TIPLOC"]==5 then
                    HealBot_Tooltip:SetPoint("TOP",g,"BOTTOM",0,0);
                else
                    HealBot_Tooltip:SetPoint("TOPLEFT","WorldFrame","BOTTOMLEFT",x+25,y-20);
                end
            else
                HealBot_Tooltip:SetPoint("BOTTOMRIGHT","WorldFrame","BOTTOMRIGHT",-105,105);
            end
        end
    end
end

local function HealBot_Tooltip_ClearLines()
    if HealBot_Globals.UseGameTooltip then
        GameTooltip:ClearLines()
    else
        for x,_ in pairs(HealBot_Tooltip_DirtyLines) do
            local txt = _G["HealBot_TooltipTextR" .. x]
            txt:SetText(" ")
            txt = _G["HealBot_TooltipTextL" .. x]
            txt:SetText(" ")
            HealBot_Tooltip_DirtyLines[x]=nil
        end
    end
end

local function HealBot_Action_GetTimeOffline(button)
    local timeOffline=nil
    if button.status.offline then
        timeOffline = GetTime() - button.status.offline;
        local seconds = math.floor(timeOffline % 60)
        local minutes = math.floor(timeOffline / 60) % 60
        local hours = math.floor(timeOffline / 3600)
        timeOffline = "";
        if hours > 0 then
            if hours == 1 then
                timeOffline = hours.." hour ";
            else
                timeOffline = hours.." hours ";
            end
        end
        if minutes > 0 then
            if minutes == 1 then
                timeOffline = timeOffline..minutes.." min ";
            else
                timeOffline = timeOffline..minutes.." mins ";
            end
        end
        if seconds > 0 then
            if seconds == 1 then
                timeOffline = timeOffline..seconds.." sec";
            else
                timeOffline = timeOffline..seconds.." secs";
            end
        end                        
    end      
    return timeOffline;
end

local function HealBot_HealthColor(button)
    local hca,hcr,hcb=0,0,0
    local hcpct,hipct=0,0

    hcr,hcg = 1, 1
    if (Healbot_Config_Skins.BarIACol[Healbot_Config_Skins.Current_Skin][button.frame]["IC"] == 3) then -- Incoming Heal Bar Colour = "Same as Health (Future Health)"
        if button.status.current<9 then
            hipct = button.health.current+button.health.incoming
            if hipct<button.health.max then
                hipct=(button.health.current+button.health.incoming)/button.health.max
            else
                hipct=1;
            end
        end
        hcr, hcg = HealBot_Action_BarColourPct(hipct)
    else 
        if button.status.current<9 then
            if button.health.max == 0 then
                hcpct=1
            else
                hcpct = button.health.current/button.health.max
            end
        end
        hcr, hcg = HealBot_Action_BarColourPct(hcpct)
    end

    return hcr,hcg,hcb
end

function HealBot_DebugTooltip()
    HealBot_Tooltip_ClearLines();
    local msgs=HealBot_retCalls()
    linenum = 1
    local leftname=false
    local leftcount=0
    for name,_ in pairs(msgs) do
        if linenum<45 then
            if leftname then
                linenum = linenum + 1
                HealBot_Tooltip_SetLine(linenum,leftname.." count="..leftcount,1,1,1,1,name.." count="..msgs[name].count,1,1,1,1)    
                leftname=false
            else
                leftname=name
                leftcount=msgs[name].count
            end      
        end
    end
    HealBot_Tooltip_Show()
end

local function HealBot_Action_DoRefreshTooltip()
    --if IsAltKeyDown() and HealBot_retCalls() then 
    --    HealBot_DebugTooltip() 
    --    return
    --end
    if HealBot_Globals.ShowTooltip==false then return end
    if HealBot_Globals.DisableToolTipInCombat and HealBot_Data["UILOCK"] then return end
    xUnit=HealBot_Data["TIPUNIT"]
    xGUID=HealBot_UnitGUID(xUnit)
    xButton=HealBot_Unit_Button[xUnit] or HealBot_Enemy_Button[xUnit] or HealBot_Pet_Button[xUnit]
    if not xGUID or not xButton then return end
    local uName=HealBot_GetUnitName(xUnit, xGUID)
    if not uName then return end;
    
    HealBot_ToolTip_SetTooltipPos();
  
    if xUnit=="target" and HealBot_Globals.TargetBarRestricted==1 then
        HealBot_Action_RefreshTargetTooltip(xButton)
        return
    end

    local hlth=xButton.health.current
    local maxhlth=xButton.health.max
    local mana=xButton.mana.current
    local maxmana=xButton.mana.max

    if hlth>maxhlth then
        maxhlth=HealBot_CorrectPetHealth(xUnit,hlth,maxhlth)
    end
  
    local UnitOffline=HealBot_Action_GetTimeOffline(xButton); --added by Diacono
    local uBuff=xButton.aura.buff.name
    local DebuffType=xButton.aura.debuff.type;

    local spellLeft = HealBot_Tooltip_SpellPattern(xButton, "Left");
    local spellMiddle = HealBot_Tooltip_SpellPattern(xButton, "Middle");
    local spellRight = HealBot_Tooltip_SpellPattern(xButton, "Right");
    local spellButton4 = HealBot_Tooltip_SpellPattern(xButton, "Button4");
    local spellButton5 = HealBot_Tooltip_SpellPattern(xButton, "Button5");
    linenum = 1

    if spellLeft and strsub(strlower(spellLeft),1,4)==strlower(HEALBOT_TELL) then spellLeft=HEALBOT_TELL end
    if spellMiddle and strsub(strlower(spellMiddle),1,4)==strlower(HEALBOT_TELL) then spellMiddle=HEALBOT_TELL end
    if spellRight and strsub(strlower(spellRight),1,4)==strlower(HEALBOT_TELL) then spellRight=HEALBOT_TELL end
    if spellButton4 and strsub(strlower(spellButton4),1,4)==strlower(HEALBOT_TELL) then spellButton4=HEALBOT_TELL end
    if spellButton5 and strsub(strlower(spellButton5),1,4)==strlower(HEALBOT_TELL) then spellButton5=HEALBOT_TELL end
  
    if not IsModifierKeyDown() and not HealBot_Data["UILOCK"] and HealBot_Globals.SmartCast and UnitExists(xUnit) and UnitIsFriend("player",xUnit) then 
        local z=spellLeft;
        spellLeft=nil;
        spellLeft=HealBot_Action_SmartCast(xButton);
        if not spellLeft then spellLeft=z; end;
    end
    if spellLeft=="" then spellLeft=nil; end
    if spellMiddle=="" then spellMiddle=nil; end
    if spellRight=="" then spellRight=nil; end
    if spellButton4=="" then spellButton4=nil; end
    if spellButton5=="" then spellButton5=nil; end
    local LeftN, LeftR, LeftG = HealBot_Tooltip_setspellName(xButton, spellLeft)
    local MiddleN, MiddleR, MiddleG = HealBot_Tooltip_setspellName(xButton, spellMiddle)
    local RightN, RightR, RightG = HealBot_Tooltip_setspellName(xButton, spellRight)
    local Button4N, Button4R, Button4G = HealBot_Tooltip_setspellName(xButton, spellButton4)
    local Button5N, Button5R, Button5G = HealBot_Tooltip_setspellName(xButton, spellButton5)

    HealBot_Tooltip_ClearLines();
    
    if HealBot_Globals.Tooltip_ShowTarget then
        if uName then
            local r,g,b=HealBot_Action_ClassColour(xUnit)
            local uLvl=UnitLevel(xUnit)
            if uLvl<1 then 
                uLvl=nil
            else
                uLvl="Level "..uLvl
            end
            local uClassify=UnitClassification(xUnit) or " "
            if uClassify=="worldboss" then 
                uClassify="Boss"
            elseif uClassify=="rareelite" then 
                uClassify="Rare Elite"
            elseif uClassify=="elite" then 
                uClassify="Elite"
            elseif uClassify=="rare" then 
                uClassify="Rare"
            else
                uClassify=nil
            end
            if uClassify then
                if uLvl then
                    uLvl=uClassify.." "..uLvl
                else
                    uLvl="Boss"
                end
            elseif not uLvl then
                uLvl=""
            end
            if UnitClass(xUnit) and UnitIsPlayer(xUnit) then
                local unitSpec = " "
                if HealBot_UnitData[xGUID] then
                    if HealBot_Globals.QueryTalents and not HealBot_Data["INSPECT"] and HealBot_UnitData[xGUID]["SPEC"]==" " then
                        HealBot_Data["INSPECT"]=true
                        HealBot_TalentQuery(xUnit)
                    end
                    unitSpec=HealBot_UnitData[xGUID]["SPEC"]
                elseif xUnit=="target" then
                    unitSpec=HealBot_retLuVars("targetSpec")
                    if HealBot_Globals.QueryTalents and not HealBot_Data["INSPECT"] and unitSpec==" " then
                        HealBot_Data["INSPECT"]=true
                        HealBot_TalentQuery(xUnit)
                    end
                elseif HealBot_Unit_Button[xUnit] then
                    HealBot_Action_SetUnitData(xGUID, xUnit)
                end
                HealBot_Tooltip_SetLine(linenum,uName,r,g,b,1,uLvl.." "..unitSpec..UnitClass(xUnit),r,g,b,1)                
            else
                HealBot_Tooltip_SetLine(linenum,uName,r,g,b,1,uLvl,r,g,b,1)      
            end      
      
            local zone=nil;
            if HealBot_Data["PGUID"]==xGUID or UnitIsVisible(xUnit) then
                zone=GetRealZoneText();
            elseif IsInRaid() and xUnit~="target" and xUnit~="focus" and UnitIsPlayer(xUnit) and UnitInRaid(xUnit) then
                local raidID=UnitInRaid(xUnit)
                _, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(raidID);
            else
                HealBot_TooltipInit();
                HealBot_ScanTooltip:SetUnit(xUnit)
                zone = HealBot_ScanTooltipTextLeft3:GetText()
                if zone == "PvP" then
                    zone = HealBot_ScanTooltipTextLeft4:GetText()
                end
            end
            linenum=linenum+1
            if hlth and maxhlth then
                local inHeal, inAbsorb = HealBot_IncHeals_retHealsIn(xUnit, xButton)
                r,g,b=HealBot_HealthColor(xButton);
                local hPct=100
                if maxhlth>0 then
                    hPct=floor((hlth/maxhlth)*100)
                end
                hlth=HealBot_Tooltip_readNumber(hlth)
                maxhlth=HealBot_Tooltip_readNumber(maxhlth)
                if UnitOffline then 
                    HealBot_Tooltip_SetLine(linenum,HB_TOOLTIP_OFFLINE..": "..UnitOffline,1,1,1,1,hlth.."/"..maxhlth.." ("..hPct.."%)",r,g,b,1)
                elseif zone and not strfind(zone,"Level") then
                    --if zone==HB_TOOLTIP_OFFLINE then xButton.status.offline = GetTime() end
                    HealBot_Tooltip_SetLine(linenum,zone,1,1,1,1,hlth.."/"..maxhlth.." ("..hPct.."%)",r,g,b,1)
                end
                local vUnit=HealBot_retIsInVehicle(xUnit)
                if vUnit then
                    linenum=linenum+1
                    local lr,lg,lb=HealBot_Action_ClassColour(vUnit)
                    hlth,maxhlth=HealBot_VehicleHealth(vUnit)
                    local hPct=floor((hlth/maxhlth)*100)
                    r,g,b=HealBot_HealthColor(xButton);
                    hlth=HealBot_Tooltip_readNumber(hlth)
                    maxhlth=HealBot_Tooltip_readNumber(maxhlth)
                    if UnitExists(vUnit) then
                        HealBot_Tooltip_SetLine(linenum,"  "..HealBot_GetUnitName(vUnit),lr,lg,lb,1,hlth.."/"..maxhlth.." ("..hPct.."%)",r,g,b,1)
                    else
                        HealBot_Tooltip_SetLine(linenum,"  "..HEALBOT_VEHICLE,lr,lg,lb,1,hlth.."/"..maxhlth.." ("..hPct.."%)",r,g,b,1)
                    end
                end
            end
            local tp=0
            if UnitIsPlayer(xUnit) then tp=HealBot_CalcThreat(xUnit) end
            HealBot_Tooltip_luVars["uGroup"]=false
            if IsInRaid() then 
                HealBot_Tooltip_luVars["uGroup"]=HealBot_RetUnitGroups(xUnit)
            end
            if tp>0 or mana or (HealBot_Tooltip_luVars["uGroup"] and HealBot_Tooltip_luVars["uGroup"]>0) then
                linenum=linenum+1
                if not mana then
                    if tp>0 then
                        HealBot_Tooltip_SetLine(linenum,HEALBOT_WORD_THREAT.." "..tp.."%",1,0.1,0.1,1," ",0,0,0,0)
                    else
                        HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_GROUPHEALS.." "..HealBot_Tooltip_luVars["uGroup"],1,1,1,1," ",0,0,0,0)
                    end
                else
                    local mPct=100
                    if maxmana>0 then
                        mPct=floor((mana/maxmana)*100)
                    end
                    mana=HealBot_Tooltip_readNumber(mana)
                    maxmana=HealBot_Tooltip_readNumber(maxmana)
                    if tp<1 then
                        if HealBot_Tooltip_luVars["uGroup"] then
                            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_GROUPHEALS.." "..HealBot_Tooltip_luVars["uGroup"],1,1,1,1,mana.."/"..maxmana.." ("..mPct.."%)",0.4,0.4,1,1)
                        else
                            HealBot_Tooltip_SetLine(linenum," ",0,0,0,0,mana.."/"..maxmana.." ("..mPct.."%)",0.4,0.4,1,1)
                        end
                    else
                        HealBot_Tooltip_SetLine(linenum,HEALBOT_WORD_THREAT.." "..tp.."%",1,0.1,0.1,1,mana.."/"..maxmana.." ("..mPct.."%)",0.4,0.4,1,1)
                    end
                end
            end
            
            UnitDebuffIcons=HealBot_retDebuffdetails(xUnit)
            if UnitDebuffIcons then
                for name,_ in pairs(UnitDebuffIcons) do
                    if name~="ExtraIcon" and UnitDebuffIcons[name].current then
                        linenum=linenum+1
                        if HealBot_Globals.CDCBarColour[name] then
                            HealBot_Tooltip_SetLine(linenum,uName.." suffers from "..name,
                                                        (HealBot_Globals.CDCBarColour[name].R or 0.4)+0.2,
                                                        (HealBot_Globals.CDCBarColour[name].G or 0.05)+0.2,
                                                        (HealBot_Globals.CDCBarColour[name].B or 0.2)+0.2,
                                                        1," ",0,0,0,0)
                        else
                            local DebuffType=HealBot_retDebufftype(name)
                            if DebuffType == HEALBOT_CUSTOM_en then
                                local customDebuffPriority=HEALBOT_CUSTOM_en.."10"
                                if HealBot_GlobalsDefaults.HealBot_Custom_Debuffs[name] then
                                    customDebuffPriority=HEALBOT_CUSTOM_en..HealBot_GlobalsDefaults.HealBot_Custom_Debuffs[name]
                                end
                                HealBot_Tooltip_SetLine(linenum,uName.." suffers from "..name,
                                                            (HealBot_Globals.CDCBarColour[customDebuffPriority].R or 0.5)+0.2,
                                                            (HealBot_Globals.CDCBarColour[customDebuffPriority].G or 0.2)+0.2,
                                                            (HealBot_Globals.CDCBarColour[customDebuffPriority].B or 0.4)+0.2,
                                                            1," ",0,0,0,0)
                            else
                                HealBot_Tooltip_SetLine(linenum,uName.." suffers from "..name,
                                                            (HealBot_Config_Cures.CDCBarColour[DebuffType].R or 0.5)+0.2,
                                                            (HealBot_Config_Cures.CDCBarColour[DebuffType].G or 0.2)+0.2,
                                                            (HealBot_Config_Cures.CDCBarColour[DebuffType].B or 0.4)+0.2,
                                                            1," ",0,0,0,0)
                            end
                        end
                    end
                end
            end
            linenum=linenum+1
            --if HealBot_Globals.UseGameTooltip then HealBot_Tooltip_SetLine(linenum,"  ",0,0,0,0) end
            if uBuff then
                linenum=linenum+1
                local br,bg,bb=HealBot_Options_RetBuffRGB(uBuff)
                HealBot_Tooltip_SetLine(linenum,"  Requires "..uBuff,br,bg,bb,1," ",0,0,0,0)
            end
            local d=false
            if HealBot_Globals.Tooltip_ShowMyBuffs then
                for x,_ in pairs(HealBot_CheckBuffs) do
                    local z=HealBot_RetMyBuffTime(xGUID,x)
                    if z then
                        d=true
                        z=z-GetTime()
                        local mins,secs=HealBot_Tooltip_ReturnMinsSecs(z)
                        linenum=linenum+1
                        local br,bg,bb=HealBot_Options_RetBuffRGB(x)
                        if mins>1 then 
                            HealBot_Tooltip_SetLine(linenum,"    "..x.."  "..mins.." mins",br,bg,bb,1," ",0,0,0,0)
                        elseif tonumber(secs)>=0 then
                            HealBot_Tooltip_SetLine(linenum,"    "..x.."  "..secs.." secs",br,bg,bb,1," ",0,0,0,0)
                        else
                            linenum=linenum-1
                            HealBot_Queue_MyBuffsCheck(xGUID, xUnit)
                        end
                    end
                end
            end
            if d then 
                linenum=linenum+1 
            end
            if HealBot_Globals.UseGameTooltip then HealBot_Tooltip_SetLine(linenum,"  ",0,0,0,0) end
            if HealBot_Globals.ProtectPvP and UnitIsPVP(xUnit) and not UnitIsPVP("player") then 
                HealBot_Tooltip_SetLine(linenum,"    ----- PVP -----",1,0.5,0.5,1,"----- PVP -----    ",1,0.5,0.5,1)
                linenum=linenum+1;
            end
        end
    else
        HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_TAB_SPELLS,1,1,1,1," ",0,0,0,0)
    end
    
    if IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown() then
        if spellLeft then 
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTONLEFT..": "..spellLeft,1,1,0,1)
        end
        if spellMiddle then
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTONMIDDLE..": "..spellMiddle,1,1,0,1)
        end
        if spellRight then
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTONRIGHT..": "..spellRight,1,1,0,1)
        end
    elseif HealBot_Globals.Tooltip_ShowSpellDetail then

        if LeftN then
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTONLEFT.." "..HEALBOT_OPTIONS_COMBOBUTTON..": "..LeftN,LeftR,LeftG,0,1) 
            HealBot_Tooltip_SpellInfo(LeftN);
            linenum=linenum+1;
        end
        if MiddleN then
            linenum=linenum+1;
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTONMIDDLE.." "..HEALBOT_OPTIONS_COMBOBUTTON..": "..MiddleN,MiddleR,MiddleG,0,1) 
            HealBot_Tooltip_SpellInfo(MiddleN);
            linenum=linenum+1;
        end
        if RightN then
            linenum=linenum+1;
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTONRIGHT.." "..HEALBOT_OPTIONS_COMBOBUTTON..": "..RightN,RightR,RightG,0,1) 
            HealBot_Tooltip_SpellInfo(RightN);
            linenum=linenum+1;
        end
        if Button4N then
            linenum=linenum+1;
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTON4.." "..HEALBOT_OPTIONS_COMBOBUTTON..": "..Button4N,Button4R,Button4G,0,1) 
            HealBot_Tooltip_SpellInfo(Button4N);
            linenum=linenum+1;
        end
        if Button5N then
            linenum=linenum+1;
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTON5.." "..HEALBOT_OPTIONS_COMBOBUTTON..": "..Button5N,Button5R,Button5G,0,1) 
            HealBot_Tooltip_SpellInfo(Button5N);
            linenum=linenum+1;
        end
    else
        if LeftN then 
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTONLEFT..": "..LeftN,LeftR,LeftG,0,1,HealBot_Tooltip_SpellSummary(spellLeft),0.5,0.5,1,1)
        end
        if MiddleN then
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTONMIDDLE..": "..MiddleN,MiddleR,MiddleG,0,1,HealBot_Tooltip_SpellSummary(spellMiddle),0.5,0.5,1,1)               
        end
        if RightN then
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTONRIGHT..": "..RightN,RightR,RightG,0,1,HealBot_Tooltip_SpellSummary(spellRight),0.5,0.5,1,1)
        end
        if Button4N then
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTON4..": "..Button4N,Button4R,Button4G,0,1,HealBot_Tooltip_SpellSummary(spellButton4),0.5,0.5,1,1)
        end
        if Button5N then
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,HEALBOT_OPTIONS_BUTTON5..": "..Button5N,Button5R,Button5G,0,1,HealBot_Tooltip_SpellSummary(spellButton5),0.5,0.5,1,1)
        end
    end      
    if HealBot_Globals.Tooltip_Recommend then    
        local spellLeftRecInstant=HealBot_Tooltip_CheckForInstant(xUnit,LeftN);
        local spellMiddleRecInstant=HealBot_Tooltip_CheckForInstant(xUnit,MiddleN)
        local spellRightRecInstant=HealBot_Tooltip_CheckForInstant(xUnit,RightN)
        local spellButton4RecInstant=HealBot_Tooltip_CheckForInstant(xUnit,Button4N)
        local spellButton5RecInstant=HealBot_Tooltip_CheckForInstant(xUnit,Button5N);
        local Instant_check=false;
        if HealBot_Globals.Tooltip_ShowSpellDetail==false then linenum=linenum+1; end
        linenum=linenum+1
        HealBot_Tooltip_SetLine(linenum,HEALBOT_TOOLTIP_RECOMMENDTEXT,0.8,0.8,0,1) 
        if spellLeftRecInstant then
            linenum=linenum+1;
            HealBot_Tooltip_SetLine(linenum,"   "..HEALBOT_OPTIONS_BUTTONLEFT..":",1,1,0.2,1,LeftN.."    ",1,1,1,1)
            Instant_check=true;
        end
        if spellMiddleRecInstant then
            linenum=linenum+1;
            HealBot_Tooltip_SetLine(linenum,"   "..HEALBOT_OPTIONS_BUTTONMIDDLE..":",1,1,0.2,1,MiddleN.."    ",1,1,1,1)
            Instant_check=true;
        end
        if spellRightRecInstant then
            linenum=linenum+1;
            HealBot_Tooltip_SetLine(linenum,"   "..HEALBOT_OPTIONS_BUTTONRIGHT..":",1,1,0.2,1,RightN.."    ",1,1,1,1)
            Instant_check=true;
        end
        if spellButton4RecInstant then
            linenum=linenum+1;
            HealBot_Tooltip_SetLine(linenum,"   "..HEALBOT_OPTIONS_BUTTON4..":",1,1,0.2,1,Button4N.."    ",1,1,1,1)
            Instant_check=true;
        end
        if spellButton5RecInstant then
            linenum=linenum+1;
            HealBot_Tooltip_SetLine(linenum,"   "..HEALBOT_OPTIONS_BUTTON5..":",1,1,0.2,1,Button5N.."    ",1,1,1,1)
            Instant_check=true;
        end
        if not Instant_check then
            linenum=linenum+1
            HealBot_Tooltip_SetLine(linenum,"  None",0.4,0.4,0.4,1) 
        end
    else
        if HealBot_Globals.Tooltip_ShowSpellDetail then linenum=linenum-1; end
    end
  
    HealBot_ToolTip_ShowHoT(xUnit)
    
    HealBot_Tooltip_Show()
end

local function HealBot_Action_DoRefreshTargetTooltip(button)
    HealBot_TooltipInit();
    HealBot_Tooltip_ClearLines();
    linenum=1
    local r,g,b=HealBot_Action_ClassColour(button.unit)

    if UnitClass(button.unit) then
        local unitSpec=" "
        if HealBot_UnitData[button.guid] then
            unitSpec = HealBot_UnitData[button.guid]["SPEC"] or " "
        end
        HealBot_Tooltip_SetLine(linenum,HealBot_GetUnitName(button.unit, button.guid),r,g,b,1,"Level "..UnitLevel(button.unit)..unitSpec..UnitClass(button.unit),r,g,b,1)    
    else
        HealBot_Tooltip_SetLine(linenum,HealBot_GetUnitName(button.unit, button.guid),r,g,b,1,rText,rR,rG,rB,ra)
    end
    linenum=linenum+1
    HealBot_Tooltip_SetLine(linenum,HEALBOT_TOOLTIP_TARGETBAR,1,1,0.5,1,HEALBOT_OPTIONS_TAB_SPELLS.." "..HEALBOT_SKIN_DISTEXT,1,1,0,1)
    linenum=linenum+2
    if HealBot_Globals.SmartCast then
        HealBot_Tooltip_SetLine(linenum," "..HEALBOT_OPTIONS_BUTTONLEFT..":",1,1,0.2,1,HEALBOT_TITAN_SMARTCAST.." ",1,1,1,1)
    end
    linenum=linenum+1
    HealBot_Tooltip_SetLineLeft(" "..HEALBOT_OPTIONS_BUTTONRIGHT..":",1,1,0.2,linenum,1)
    if HealBot_Panel_RetMyHealTarget(button.guid) then
        HealBot_Tooltip_SetLine(linenum," "..HEALBOT_OPTIONS_BUTTONRIGHT..":",1,1,0.2,1,HEALBOT_WORDS_REMOVEFROM.." "..HEALBOT_OPTIONS_TARGETHEALS.." ",1,1,1,1)
    else
        HealBot_Tooltip_SetLine(linenum," "..HEALBOT_OPTIONS_BUTTONRIGHT..":",1,1,0.2,1,HEALBOT_WORDS_ADDTO.." "..HEALBOT_OPTIONS_TARGETHEALS.." ",1,1,1,1)
    end
    HealBot_Tooltip_Show()
end

function HealBot_Action_RefreshTooltip()
    HealBot_Action_DoRefreshTooltip()
end

function HealBot_Action_RefreshTargetTooltip(button)
    HealBot_Action_DoRefreshTargetTooltip(button)
end

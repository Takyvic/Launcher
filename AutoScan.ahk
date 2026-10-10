#Requires AutoHotkey v2.0
#SingleInstance
DetectHiddenWindows true

exe := "\SudokuDots5.exe"

params := "ZiqTSIVwfdbC -v 11 -d 0 -e 50 -s 1 -k2 40 -kr 57 -k3 25 -kh 66 -b2 50"
; params := "WCixDtTdpXtC -v 12 -d 40 -e 60 -s 0 -k1 20 -kq 35 -bx 90 -lg 0 -gs 3"
; params := "QiwgXGzbQmrG -v 12 -d 35 -e 60 -s 1 -cx 258 -cy 159 -gs 2"
; params := "IuUHZzsRLkal -v 11 -d 0 -e 20 -s 0 -ki 46 -kt 37 -b3 40 -ck 12 -lg 4 -gv 6"
; params := "AWnPMXPLOVJZ -v 11 -d 50 -e 0 -s 1 -k1 25 -kb 35 -k2 30 -kw 47 -bk 60 -cd 2 -lg 5 -gv 5"
; params := "AfJuxbcUHugC -v 11 -d 30 -e 40 -s 1 -k1 25 -kb 45 -k2 30 -kw 47 -b4 80 -b5 50 -lg 6 -gv 6"
; params := "ZuhDlcjovVaC -v 11 -d 0 -e 40 -s 0 -k2 50 -kr 46 -b2 30 -b3 40 -b4 50 -lg 6 -gx 20"
; params := "EGlDiGVYNgrq -v 11 -d 0 -e 70 -s 1 -k2 50 -kr 46 -b2 30 -b3 40 -b4 50 -lg 8 -gx 25"
; params := "TTcTlezzJMEj -v 11 -d 50 -e 60 -s 1 -k2 50 -kr 46 -lg 2"
tries := ["10", "25", "50", "100", "500", "1000", "2000"]
seedType := 0, scans := [], startTime := 0

hash(str, x) {
    hash := 5381
    loop parse str {
        c := Ord(A_LoopField)  ; Get ASCII value of character
        hash := ((hash << 5) + hash) + (c ^ x)
    }
    return hash
}

captureScan(s) {
    oldClip := A_Clipboard								; Save original clipboard
    A_Clipboard := ""
    ControlSend "^a^c" ,, "ahk_pid " s.pid				; Send Ctrl+A and Ctrl+C
    if !ClipWait(0.5) {									; Wait for clipboard to contain data
        A_Clipboard := oldClip  						; Restore on timeout
        return
    }
    clip := A_Clipboard
    A_Clipboard := oldClip  ; Restore original
    
    idx := StrSplit(clip, "_")
    for i, val in idx {
        if(strlen(val) > 1) {
            index := RegExMatch(val, "^\d+", &match) ? match[0] : ""
            cand := RegExMatch(val, "#(\d+)#", &match) ? match[1] : ""
            score := RegExMatch(val, "(\[.*?\])", &match) ? match[1] : ""
			vees := InStr(score, "V")
			zeds := InStr(score, "Z")
            
            if(cand) {
                scanOutput2.Add(, s.params . " -x " . index, cand . " " . score)                             
            }
			if(vees || zeds) {
				scanOutput2.Add(, s.params . " -x " . index, score)
			}
			if(InStr(score, "Q")) {
				scanOutput2.Add(, s.params . " -x " . index, score)
			}
        }
    }
}

grabScan() {
    Global scans
    
    ; Loop through existing processes to check status
    For scanIndex, scan in scans {
        if(WinExist("ahk_pid " scan.pid)) {
			if(Not InStr(WinGetTitle("ahk_pid " scan.pid), "SudokuDots")) {
				captureScan(scan)
				WinClose("ahk_pid " scan.pid)
				scans.RemoveAt(scanIndex)  ; Remove completed instance
			}
        }
    }
    
    ; Start new instance if we should (you may want to limit max instances)
    maxInstances := processes.value ; Set your desired max concurrent instances
    if(scans.Length < maxInstances) {
        ; Generate random string (your existing logic)
        Chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        Result := ""
        Loop {
            Result := ""
            Loop 12 {
                RandNum := Random(1, A_Index == 1 ? 26 : StrLen(Chars))
                Result .= SubStr(Chars, RandNum, 1)
            }
        } Until hash(Result, 0xFF) & 0x1FF == seedType
        
        paramText.Value := RegExReplace(paramText.Value, "^\S+", Result)
        
        rw := "cmd.exe /k " . exe . " " . paramText.Value . " -t " . tries[slider.Value] . " "
		; Run(rw, , , &newPID)
        Run(rw, , "Min", &newPID)
        scans.Push({pid: newPID, params: paramText.Value})
        WinWait("ahk_pid " newPID)
    }
    
    ; Update timer
    SetTimer grabScan, 2000
    
    ; Update elapsed time display (assuming startTime is global)
    Global startTime
    elapsedMs := A_TickCount - startTime
    hours := Floor(elapsedMs / (1000 * 60 * 60))
    minutes := Floor(Mod(elapsedMs, (1000 * 60 * 60)) / (1000 * 60))
    seconds := Floor(Mod(elapsedMs, (1000 * 60)) / 1000)
    elapsed.Value := Format("{:02}:{:02}:{:02}", hours, minutes, seconds)
}


Scan(*) {
	Global scanPID, startTime
	if(scanBtn.Text == "Scan") {
		scanBtn.Text := "Close"
		elapsed.Value := "00:00:00"
		startTime := A_TickCount
		SetTimer grabScan, 10
	} else {
		scanBtn.Text := "Scan"
		SetTimer grabScan, 0
	
		i := scans.Length
		while (i >= 1) {
			scan := scans[i]
			if WinExist("ahk_pid " scan.pid) {
				captureScan(scan)
				WinClose("ahk_pid " scan.pid)
				scans.RemoveAt(i)
			}
			i--  ; Decrement after processing
		}
		scanPID := []
	}
}

Copy(*) {
	txt := ""
	Loop scanOutput2.getCount() {
		command := scanOutput2.getText(A_Index, 1)
		fill := StrReplace(Format("{:" ((94-strlen(command))/4) "}", ""), " ", "`t")
		txt .= command . fill . scanOutput2.getText(A_Index, 2) . "`n"
	}
	A_Clipboard := txt
}

paramText_change(*) {
	Global seedType

	strBase := (paramText.Value) ? StrSplit(paramText.Value, " ")[1] : ""
	seedType := hash(strBase, 0xFF) & 0x1FF
}

hParamFull(*) {
	paramText.Value := RegExReplace(A_Clipboard, " -[ax]\s+\S+")
	paramText_change()
	scanOutput2.Delete()
}

ListViewContextMenu(LV, Item, IsRightClick, X, Y) {
	A_Clipboard := LV.GetText(Item, 1)
}

;//////////////////////// MAIN //////////////////////////////
; Create GUI with options
myGui := Gui("+MinSize", "AutoScan")

paramText := myGui.Add("Edit", "Section w800 h18 BackgroundWhite Border")
paramText.SetFont("s8", "Consolas")

myGui.Add("Text", "Section", "Processes:")
processes := myGui.Add("Slider", "ys w80", 3)
processes.Opt("Range1-" . 3)
paramFull := myGui.Add("Button", "ys w80", "Full")
paramFull.OnEvent("Click", hParamFull)
scanBtn := myGui.Add("Button", "ys w80", "Scan")
scanBtn.OnEvent("Click", Scan)
myGui.Add("Text", "ys", "Tries:")
slider := MyGui.Add("Slider", "ys vMySlider", 5)
slider.Opt("Range1-" . tries.length)
copyBtn := myGui.Add("Button", "ys w80", "Copy")
copyBtn.OnEvent("Click", Copy)
elapsed := myGui.Add("Text", "ys x740 h20 w80", "00:00:00")
elapsed.SetFont("s12", "Tahoma")

scanOutput2 := myGui.Add("ListView", "Section xs w800 h340", ["Command", "Candidates"])
scanOutput2.ModifyCol(1, 640)
scanOutput2.ModifyCol(2, 200)
scanOutput2.SetFont("s9", "Consolas")
scanOutput2.OnEvent("ContextMenu", ListViewContextMenu)

copyDir := DirExist("R:\") ? "R:\" : ""
if (SubStr(A_ScriptFullPath, -3) == "ahk") {
	orgFile := "P:\Google_Drive\Projects\CodeBlocks\SudokuDots5\bin\Debug" . exe
	if(copyDir == "R:\") {
		FileCopy(orgFile, copyDir, 1)
		exe := copyDir . exe
	} else {
		exe := orgFile
	}
} else {
	SplitPath(A_ScriptFullPath, &fileName, &fileDir)
	orgFile := fileDir . exe
	if(!FileExist(orgFile)) {
		msgbox orgFile . " Not Found"
		Exit
	}
	if(copyDir == "R:\") {
		FileCopy(orgFile, copyDir, 1)
		exe := copyDir . exe
	} else {
		exe := orgFile
	}
}

myGui.Show("w820 h440")
scanOutput2.Focus()

paramText.Value := params
paramText_change()


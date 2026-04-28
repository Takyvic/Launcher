#Requires AutoHotkey v2.0
#SingleInstance
DetectHiddenWindows true

exe := "\SudokuDots5.exe"

params := "DhwpklXnmiLx -v 11 -d 40 -e 50 -s 1 -k2 50 -kr 46 -b3 25 -b4 40 -lg 3"
; params := "TTcTlezzJMEj -v 11 -d 50 -e 60 -s 1 -k2 50 -kr 46 -lg 2"
tries := ["10", "25", "50", "100", "500", "1000", "2000"]
seedType := 0, scanPID := 0, startTime := 0

hash(str, x) {
    hash := 5381
    loop parse str {
        c := Ord(A_LoopField)  ; Get ASCII value of character
        hash := ((hash << 5) + hash) + (c ^ x)
    }
    return hash
}

grabScan() {
	Global scanPID
	
	if(scanPID == 0) {
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
		Run(rw, , "Min", &scanPID)
		WinWait("ahk_pid " scanPID)
		SetTimer grabScan, 2000
	}
	if(scanPID) {
		if(WinExist("ahk_pid " scanPID)) {	
			ControlSend "^a^c" ,, "ahk_pid " scanPID
			clip := A_Clipboard
			if(clip == "")
				return
			idx := StrSplit(clip, "_")
			
			for i, val in idx {
				if(strlen(val) > 1) {
					; index :=  StrSplit(val, " ")[1]
					index := RegExMatch(val, "^\d+", &match) ? match[0] : ""
					cand := RegExMatch(val, "#(\d+)#", &match) ? match[1] : ""
					score := RegExMatch(val, "(\[.*?\])", &match) ? match[1] : ""
					
					if(cand) {
						command := paramText.Value . " -x " . index
						existing := false	; Check if item already exists
						Loop scanOutput2.getCount() {
							if(scanOutput2.getText(A_Index) == command) {
								existing := true
								Break
							}
						}
						if(!existing) 
							scanOutput2.Add(, command, cand . " " . score)
						
					}
				}
			}
			
			last := StrSplit(idx[idx.Length], " ")[1]
			if(isNumber(last)) {
				scanOutput1.Value := last
			} else {
				if(WinExist("ahk_pid " scanPID))
					WinClose ("ahk_pid " scanPID)
				scanPID := 0
				SetTimer grabScan, 10
			}

		}
	}
	
	elapsedMs := A_TickCount - startTime	; Calculate elapsed milliseconds
	hours := Floor(elapsedMs / (1000 * 60 * 60))	; Convert to hh:mm:ss
	minutes := Floor(Mod(elapsedMs, (1000 * 60 * 60)) / (1000 * 60))
	seconds := Floor(Mod(elapsedMs, (1000 * 60)) / 1000)
	elapsed.Value := Format("{:02}:{:02}:{:02}", hours, minutes, seconds)	; Format with leading zeros
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
		if(WinExist("ahk_pid " scanPID))
			WinClose ("ahk_pid " scanPID)
		scanPID := 0
	}
}

Copy(*) {
	txt := ""
	Loop scanOutput2.getCount() {
		command := scanOutput2.getText(A_Index, 1)
		fill := StrReplace(Format("{:" ((90-strlen(command))/4) "}", ""), " ", "`t")
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

paramText := myGui.Add("Edit", "Section w700 h18 BackgroundWhite Border")
paramText.SetFont("s8", "Consolas")

scanOutput1 := myGui.Add("Text", "Section w50 h20 BackgroundWhite Border")
paramFull := myGui.Add("Button", "ys w80", "Full")
paramFull.OnEvent("Click", hParamFull)
scanBtn := myGui.Add("Button", "ys w80", "Scan")
scanBtn.OnEvent("Click", Scan)
myGui.Add("Text", "ys", "Tries:")
slider := MyGui.Add("Slider", "ys vMySlider", 4)
slider.Opt("Range1-" . tries.length)
copyBtn := myGui.Add("Button", "ys w80", "Copy")
copyBtn.OnEvent("Click", Copy)
elapsed := myGui.Add("Text", "ys x640 h20 w80", "00:00:00")
elapsed.SetFont("s12", "Tahoma")

scanOutput2 := myGui.Add("ListView", "Section xs w700 h340", ["Command", "Candidates"])
scanOutput2.ModifyCol(1, 540)
scanOutput2.ModifyCol(2, 140)
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
	; "P:\Google_Drive\Projects\AutoHotKey\AutoScan.exe"
}

myGui.Show("w720 h440")
scanOutput2.Focus()
; orgFile := "P:\Google_Drive\Projects\CodeBlocks\SudokuDots5\bin\Debug\SudokuDots5.exe"
; copyDir := "R:\"
; for n, GivenPath in A_Args  ; For each parameter (or file dropped onto a script):
; {
    ; Loop Files, GivenPath, "FD"  ; Include files and directories.
        ; LongPath := A_LoopFileFullPath
	; if (n = 1)
	; {
		; orgFile := LongPath
		; copyDir := ""
	; }
	; if (n = 2)
		; copyDir := LongPath
; }
; if (copyDir = "")
; {
	; exe := orgFile
; }
; else
; {
	; FileCopy(orgFile, copyDir, 1)
	; exe := copyDir . SubStr(orgFile, InStr(orgFile, "\", 0, -1) + 1)
; }
paramText.Value := params
paramText_change()


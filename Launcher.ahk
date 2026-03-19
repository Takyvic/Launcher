#SingleInstance
DetectHiddenWindows true

exe := "R:\SudokuDots5.exe"

params := "NnMqwQSUgIsN -v 11 -d 60 -e 50 -s 0 -x 0"
; params := "OiLkdtEownzD -v 11 -d 30 -e 0 -k1 20 -ka 44 -k2 60 -kw 46 -k3 60 -kt 46 -lg 2 -gv 3 -gx 28"
; params := "StQwIZSLfguL -v 11 -d 30 -e 60 -k1 30 -ka 34 -k2 50 -kr 46 -k3 50 -kt 46 -bd 50 -bk 60 -b3 50 -b4 50 -lg 1 -gv 4 -x 1"
; params := "Wounstacn -v 11 -d 50 -e 50 -gn 5"
; params := "Wounstacn -v 11 -d 75 -e 40 -kr 56 -lg 5 -a 1a1"
controls := [], radios := [], tries := ["10", "25", "50", "100", "500", "1000", "2000"]
seedType := 0, Solved := 0
scanPID := 0, runPID := 0

SortArray(arr, options := "") {
    ; Convert array to delimited string
    str := ""
    for i, v in arr
        str .= v "`n"
    
    ; Sort the string and remove duplicates (U option)
    str := Sort(str, "U " options)  ; U for unique
    
    ; Convert back to array
    result := []
    loop parse, str, "`n"
        if A_LoopField != ""
            result.Push(A_LoopField)
    
    return result
}

RunWaitOne(tries, idx) {
	Global runPID
	A_Clipboard := ""
	cnt := 0
	Run(A_ComSpec . " /k  " . exe . " " . paramText.Value . " -t " . tries . " -x " . idx . " | Clip", , "Hide", &runPID)
	Loop {
		cnt++
		Sleep 20
	} Until A_Clipboard || cnt == 1200
	WinClose ("ahk_pid " runPID)
	res := A_Clipboard
	runPID := 0
	Return res
}

hash(str, x) {
    hash := 5381
    loop parse str {
        c := Ord(A_LoopField)  ; Get ASCII value of character
        hash := ((hash << 5) + hash) + (c ^ x)
    }
    return hash
}

processText(mode, button, info := 0) {
    ; Get the GUI from the button control
    parentGui := button.Gui
    
    ; Loop through ALL controls and find Text controls
    for ctrl in parentGui {
        if ctrl.Type = "Text" {
            text := ctrl.Value
        }
    }
    
    if (mode = "send") {
        ; Just copy filtered text and send to Chrome
        A_Clipboard := text
        if(WinExist("ahk_exe chrome.exe")) {
            WinActivate("ahk_exe chrome.exe")
            Send("{ESC}{F9}")
            Send("^V")
        }
    } else {
		; Filter lines that start with (XX) where XX is two uppercase letters
		filtered := ""
		Loop Parse, text, "`n", "`r"
		{
			if RegExMatch(A_LoopField, '^\([A-Z]{2}') {
				filtered .= A_LoopField . "`n"
			}
		}
	
	
		if (mode = "url") {
			; Create URL from filtered text
			; Create a binary buffer for the UTF-8 bytes
			buf := Buffer(StrPut(filtered, "UTF-8"))
			StrPut(filtered, buf, "UTF-8")	
			; Convert each byte to percent encoding if needed
			encoded := ""
			loop buf.Size {
				byte := NumGet(buf, A_Index - 1, "UChar")
				if (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || 
					(byte >= 0x61 && byte <= 0x7A) || (byte == 0x2D) || (byte == 0x2E) {
					; Alphanumeric characters remain as-is
					encoded .= Chr(byte)
				} else if (byte == 0x20) {
					encoded .= "_"
				} else {
					; All other characters become %XX
					encoded .= Format("%{:02X}", byte)
				}
			}
			
			; url := "file:///P:/Google_Drive/Projects/VSCode/HTML/Sudoku%20Step/index.html?g="
			url := "https://" . "sudokustep.netlify.app/?g="
			A_Clipboard := url . encoded
		}
		else if (mode = "filter") {
			; Just copy filtered text (original SolveSend behavior)
			A_Clipboard := filtered
			if(WinExist("ahk_exe chrome.exe")) {
				WinActivate("ahk_exe chrome.exe")
				Send("{ESC}{F9}")
				Send("^V")
			}
		}
	}
}

Solve(tries) {
	Global Solved
	idx := ControlGetItems(indexList)
	if(idx.length == 0)
		idx.push("0")
	for i in idx {
		result := RunWaitOne(tries, i)
		if(tries == 0) {
			myGui2 := Gui("-MinimizeBox")
			solveButton := myGui2.Add("Button", "x400 w200", "Send")			
			solveButton.OnEvent("Click", processText.Bind("send"))
			; Optionally, set a custom font and size
			myGui2.SetFont("s10", "Consolas") 
			; Add text to the GUI. w350 sets the width of the text control.
			myGui2.Add("Text", "x10", result)
			; Display the GUI
			myGui2.Show("w1024")
		} else {
			myGui2 := Gui("-MinimizeBox")
			urlButton := myGui2.Add("Button", "x50 Section w200", "URL")
			urlButton.OnEvent("Click", processText.Bind("url"))	
			filterButton := myGui2.Add("Button", "ys xs225 w200", "Filter Steps")
			filterButton.OnEvent("Click", processText.Bind("filter"))		
			solveButton := myGui2.Add("Button", "ys xs450 w200", "Send")
			solveButton.OnEvent("Click", processText.Bind("send"))
			myGui2.SetFont("s8", "Consolas") 
			myGui2.Add("Text", "x10 w960", "Dots = " . StrLen(RegExReplace(result, "[^.]", "")))
			; Add text to the GUI. w350 sets the width of the text control.
			myGui2.Add("Text", "w960", StrReplace(result, "&", "&&"))
			; Display the GUI
			myGui2.Show("w960")
		}
	}
	Solved := 1
}

;////////////////////// GUI CALLS ////////////////////////////

UpdateSeedType(radioCtrl, *)
{
	Global seedType
	seedType := seedType ^ (1 << radioCtrl.Index)
	Loop radios.Length
		radios[A_Index].Value := (seedType >> (9 - A_Index)) & 1
}

grabScan() {
	Global runPID
	if(WinActive(myGui.Hwnd) && runPID == 0) {	
	; if(WinActive("A") == myGui.Hwnd) {
		if(WinExist("ahk_pid " scanPID)) {
			ControlSend "^a^c" ,, "ahk_pid " scanPID
			clip := A_Clipboard
			if(clip == "")
				return
			idx := StrSplit(clip, "_")
			if(InStr(clip, "AutoHotKey")) {
				SetTimer , 0
			}
			last := StrSplit(idx[idx.Length], " ")[1]
			if(isNumber(last))
				scanOutput1.Value := last
			scanOutput2.Delete
			scanOutput3.Delete
			for i, val in idx {
				if(strlen(val) > 1) {
					idx :=  StrSplit(val, " ")[1]
					if(RegExMatch(val, "\[(.*?)\]", &score))
						scanOutput2.Add("", idx, RegExMatch(score[1], "^-?\d+", &match) ? match[0] : "",
												 RegExMatch(score[1], ",s(\d+)", &match) ? match[1] : "", 
												 RegExMatch(score[1], " (\D+)", &match) ? match[1] : "")				
						; scanOutput2.Add("", idx, RegExMatch(score[1], "^\d+", &match) ? match[0] : "",
												 ; RegExMatch(score[1], ",s(\d+)", &match) ? match[1] : "", 
												 ; RegExMatch(score[1], " (\D+)", &match) ? match[1] : "")
					if(RegExMatch(val, "\#(.*?)\#", &cand))
						scanOutput3.Add("", idx, cand[1])
					if(InStr(val, "V") && InStr(val, "]"))
						scanOutput3.Add("", idx, "V")
				}
			}
			ControlSend "^{End}", scanOutput2
			ControlSend "^{End}", scanOutput3
		} else {
			SetTimer , 0
		}
	}
}

Scan(*) {
	Global scanPID
	if(scanPID == 0) {
		indexList.Delete()
		scanBtn.Text := "Close"
		rw := "cmd.exe /k " . exe . " " . paramText.Value . " -t " . tries[slider.Value] . " "
		; Run(rw, , "Min", &scanPID)
		Run(rw, , , &scanPID)
		WinWait("ahk_pid " scanPID)
		WinMove(100, 0, , , "ahk_pid " scanPID)
		WinActivate ("ahk_id" myGui.Hwnd)
		SetTimer grabScan, 2000
	} else {
		scanBtn.Text := "Scan"
		if(WinExist("ahk_pid " scanPID))
			WinClose ("ahk_pid " scanPID)
		scanPID := 0
	}
}

OnMessage(0x0200, On_WM_MOUSEMOVE)
On_WM_MOUSEMOVE(wParam, lParam, msg, Hwnd)
{
    static PrevHwnd := 0
    if (Hwnd != PrevHwnd)
    {
        Text := "", ToolTip() ; Turn off any previous tooltip.
        CurrControl := GuiCtrlFromHwnd(Hwnd)
        if CurrControl
        {
            if !CurrControl.HasProp("ToolTip")
                return ; No tooltip for this control.
            Text := CurrControl.ToolTip
            SetTimer () => ToolTip(Text), -1000
            SetTimer () => ToolTip(), -4000 ; Remove the tooltip.
        }
        PrevHwnd := Hwnd
    }
}

Param_Change(*) {
	paramText.Value := strBase.Value
	for p in controls {
		if(SubStr(p.type, 1, 1) == " " && p.id != "a")	
		; if(SubStr(p.type, 1, 1) == " ")
			p.checkbox.Value := 1
		if(p.checkbox.Value) {
			val := p.edit.value
			if(val != "") {
				paramText.Value .= " -" . (p.type != " " ? p.type : "") . p.id . " " . val
			
			}
		}
	}
	if(sampleCheck.Value) {
		res := RunWaitOne(0, 0)
		if(res && WinExist("ahk_exe chrome.exe")) {
			WinActivate("ahk_exe chrome.exe")  ; or firefox.exe, msedge.exe, etc.
			Send("{ESC}{F9}")
			; Sleep(20)
			Send("^V")
		}

	}
}

paramText_change(*) {
	Global seedType
	; Extract all parameters with values using RegEx
	params := []
	pos := 1
	while (pos := RegExMatch(paramText.Value, " -(\S+)\s+(\S+)", &match, pos)) {
		params.Push({key: match[1], value: match[2]})
		pos += match.Len[0]
	}
	; debugGui := Gui("-MinimizeBox")
	; for p in params {
		; debugGui.Add("Text", , p.key . " " . p.value)
	; }
	; for p in controls {
		; debugGui.Add("Text", , "type:" . p.type . " id:" . p.id)
	; }
	; debugGui.Show("w400")

	; Display results
	for p in controls {
		for param in params {
			if(strLen(param.key) == 1) {
				type := " "
				id := substr(param.key, 1, 1)
			} else {
				type := substr(param.key, 1, 1)
				id := substr(param.key, 2, 1)
			}
			if(p.type == type && p.id == id) {
				p.edit.value := param.value
				p.checkbox.Value := 1
				break
			} else {
				p.checkbox.Value := 0
			}
		}		
	}

	if(paramText.Value)
		strBase.Value := StrSplit(paramText.Value, " ")[1]
	seedType := hash(strBase.Value, 0xFF) & 0x1FF
	Loop radios.Length
		radios[A_Index].Value := (seedType >> (9 - A_Index)) & 1
}

hParamFull(*) {
	paramText.Value := A_Clipboard
	if RegExMatch(paramText.Value, "-x\s+(\d+)", &match) {
		indexList.Delete()
		indexList.Add([match[1]])
	}	

	paramText_change()
	Param_Change()
}

hParamSeed(*) {
	paramText.Value := RegExReplace(paramText.Value, "^\w+", A_Clipboard)
	paramText_change()
}

hParamTextClick(*) {
	items := ControlGetItems(indexList)
	dashX := " -x 0"
	if(items.Length)
		dashX := " -x " . items[1]
	A_Clipboard := paramText.Value . dashX
}

generateClick(*) {
    Chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    Result := ""
	
	Loop {
		Result := ""
		Loop 12 {
			RandNum := Random(1, A_Index == 1 ? 26 : StrLen(Chars))
			Result .= SubStr(Chars, RandNum, 1)
		}
	} Until hash(Result, 0xFF) & 0x1FF == seedType
	strBase.Value := Result
}

AddControls(control) {
	indent := 0
	for i, text in control {
		if(text == "") {
			indent := 1
			Continue
		}
		var1 := StrSplit(text, ".")[1]
		var2 := StrSplit(text, ".")[2]

		if(var1 == " a")
			width := "w100"
		else
			width := StrLen(var2) > 8 ? "w60" : StrLen(var2) > 4 ? "w35" : "w25"
			
		if(indent == 1) {
			indent := 0
			cb := myGui.Add("CheckBox", "xs Section x80", var1)
		} else {
			cb := myGui.Add("CheckBox", (i = 1 ? "xs Section x8" : "ys xp40"), var1)
		}
		eb := myGui.Add("Edit", "ys xp32 h15 " . width , var2)
		cb.OnEvent("Click", Param_Change)
		eb.OnEvent("Change", Param_Change)
		cb.ToolTip := StrSplit(text, ".")[3]
		eb.ToolTip := StrSplit(text, ".")[4]
		controls.Push({checkbox: cb, edit: eb, label: text, type: SubStr(var1, 1, 1), id: SubStr(var1, -1)})
	}
}

ListViewClick(LV, Row) {
	Global Solved

	items := []
    ; Get all items from ListBox
	if(Solved == 0)
		items := ControlGetItems(indexList)
	items.push(LV.GetText(Row, 1))
	
    ; Sort the array
    items := SortArray(items)
    
    ; Clear and re-add sorted items
    indexList.Delete()
    indexList.Add(items)
	Solved := 0
	
/*     ; Get all items from ListBox
    items := ControlGetItems(indexList)
	items.push(LV.GetText(Row, 1))
	
    ; Sort the array
    items := SortArray(items)
    
    ; Clear and re-add sorted items
    indexList.Delete()
    indexList.Add(items) */
}

ListBoxClick(*) {
	indexList.Delete()
}

;//////////////////////// MAIN //////////////////////////////
; Create GUI with options
myGui := Gui("+MinSize", "Launcher")

strBase := myGui.Add("Edit", "Section h20 w300")
strBase.SetFont("s10", "Consolas")
strBase.OnEvent("Change", Param_Change)
strBase.OnEvent("Focus", Param_Change)
generate := myGui.Add("Button", "ys", "Generate")
generate.OnEvent("Click", generateClick)

; Create 9 radio buttons in a row
Loop 9 {
    ; radio := MyGui.Add("Radio", "vRadio" A_Index " x" (400 + (A_Index-1)*16) " y0 w15 h30" " Group")
	radio := MyGui.Add("Radio", " x" (400 + (A_Index-1)*16) " ys-2 w15 h30" " Group")
	radio.Index := 9 - A_Index  ; Store the index as a property
    radio.OnEvent("Click", UpdateSeedType)
    radios.Push(radio)
}

AddControls([" v.11.Variant.", " d.50.Dots.Percent.", " e.50.Extended.Percent.", " s.1.First Digit.0 / 1"])
AddControls(["k1.100.Quantity.Percent", "ka.44.Arrow Sum.", "kb.44.Between.", "kp.44.Split Pea.", "kq.44.Product Sum.", "kl.44.Lockout."])
AddControls(["k2.100.Quantity.Percent", "kr.44.Renban.", "kw.44.German Whisper.", "kd.44.Dutch Whisper.", 
			"ky.44.Parity.", "km.44.Modular." , "ke.44.Entropy.", "kz.44.Zipper."])
AddControls(["", "ks.44.Region Sum.", "kn.44.Nabner.", "kx.44.Ten.", "ki.44.Index." , "kf.44.Anti-Factor."])
AddControls(["k3.100.Quantity.Percent.", "kt.44.Thermo."])
AddControls(["lr.00000.Renban.DAaBbCc.", "lw.00000.German Whisper.DAaBbCc.", "ld.00000.Dutch Whisper.DAaBbCc.",
			"lp.00000.Parity.DAaBbCc.", "lm.00000.Modular.DAaBbCc.", "le.00000.Entropy.DAaBbCc.",
			"lz.00000.Zipper.DAaBbCc.", "lt.00000.Thermo.DAaBbCc."])
AddControls(["bd.100.Dots.Quantity.", "bk.100.Kropki.Quantity.", "bx.100.X.Quantity.", "bv.100.V.Quantity.",
			"b2.100.Cage 2.Quantity.", "b3.100.Cage 3.Quantity.", "b4.100.Cage 4.Quantity.", 
			"b5.100.Cage 5.Quantity.", "b6.100.Cage 6.Quantity.", "b7.100.Cage 7.Quantity."])
AddControls(["cd.3.Diagonal.1=pos, 2=neg", "cj.1.Disjoint.0 / 1", "ck.12.Fairy.XY", "cc.1.Consecutive.0 / 1", 
			"ce.1.Entropy.1 / 2", "cm.1.Modular.1 / 2", "cs.13.Sum.Sum", "cx.314.Row Sequence.xyz",
			"cy.159.Col Sequence.xyz", "ca.4.Adjacent.abcd or n"])
AddControls(["lg.0.Light.Quantity.", "gn.0.Givens.Quantity.", "gv.6.Given V.Min Quantity.", "gx.25.Given X.Min Quantity.",
			" a..Remove Canditate.nAR"])

paramText := myGui.Add("Text", "xs Section w700 h16 BackgroundWhite Border")
paramText.SetFont("s8", "Consolas")
paramText.OnEvent("Click", hParamTextClick)

paramFull := myGui.Add("Button", "xs Section", "Full")
paramFull.OnEvent("Click", hParamFull)
paramSeed := myGui.Add("Button", "ys", "Seed")
paramSeed.OnEvent("Click", hParamSeed)
myGui.Add("Text", "ys", "Tries:")
slider := MyGui.Add("Slider", "ys vMySlider", 4)
slider.Opt("Range1-" . tries.length)


scanOutput1 := myGui.Add("Text", "x10 Section w50 h20 BackgroundWhite Border")
scanBtn := myGui.Add("Button", "ys xs120 w80", "Scan")
scanBtn.OnEvent("Click", Scan)
singlePassBtn := myGui.Add("Button", "yp w80", "Single")
singlePassBtn.OnEvent("Click", (*) => (Solve(45)))
doublePassBtn := myGui.Add("Button", "yp w80", "Double")
doublePassBtn.OnEvent("Click", 	(*) => (Solve(1)))
sampleBtn := myGui.Add("Button", "yp w80", "Sample")
sampleBtn.OnEvent("Click", (*) => (Solve(0)))
sampleCheck := myGui.Add("CheckBox", "yp ys4", "Auto-Sample")

scanOutput2 := myGui.Add("ListView", "Section xs w240 h120", ["Index", "Score", "Sum", "Extra"])
scanOutput2.ModifyCol(1, "Integer Left")
scanOutput2.ModifyCol(2, 40)
scanOutput2.ModifyCol(3, 40)
scanOutput2.ModifyCol(4, 100)
scanOutput2.OnEvent("Click", ListViewClick)
scanOutput3 := myGui.Add("ListView", "ys w240 h120", ["Index", "Candidates"])
scanOutput3.ModifyCol(1, "Integer Left")
scanOutput3.ModifyCol(2, 200)
scanOutput3.OnEvent("Click", ListViewClick)
indexList := myGui.Add("ListBox", "ys w100 h120")
indexList.OnEvent("Focus", ListBoxClick)

myGui.Show("w720 h440")

orgFile := "P:\Google_Drive\Projects\CodeBlocks\SudokuDots5\bin\Debug\SudokuDots5.exe"
copyDir := "R:\"
for n, GivenPath in A_Args  ; For each parameter (or file dropped onto a script):
{
    Loop Files, GivenPath, "FD"  ; Include files and directories.
        LongPath := A_LoopFileFullPath
	if (n = 1)
	{
		orgFile := LongPath
		copyDir := ""
	}
	if (n = 2)
		copyDir := LongPath
}
if (copyDir = "")
{
	exe := orgFile
}
else
{
	FileCopy(orgFile, copyDir, 1)
	exe := copyDir . SubStr(orgFile, InStr(orgFile, "\", 0, -1) + 1)
}

paramText.Value := params
paramText_change()
if RegExMatch(paramText.Value, "-x\s+(\d+)", &match) {
	indexList.Delete()
	indexList.Add([match[1]])
}
Param_Change()

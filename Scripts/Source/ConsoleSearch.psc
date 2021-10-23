scriptName ConsoleSearch
{Get `help` results from the console}

; Returns the raw returned text from running `help "[query]"` in the console
string function Help(string query) global
    ; Check if console is currently open
    bool consoleOpen = UI.GetBool("Console", "_global.Console.ConsoleInstance.Shown")

    ; Is ConsoleUtil installed?
    bool consoleUtilInstalled = ConsoleUtil.GetVersion()

    ; Is it initialized? Check.
    float consoleInitialized = UI.GetFloat("Console", "_global.Console.ConsoleInstance._SearchInitialized")

    ; Initialize by opening the console at least once (then you can immediately close it)
    if ! consoleInitialized
        if ! consoleOpen
            Input.TapKey(Input.GetMappedKey("Console")) ; Open
            ; Wait for it to be Shown
            while ! UI.GetBool("Console", "_global.Console.ConsoleInstance.Shown")
                Utility.WaitMenuMode(0.01)
            endWhile
            consoleOpen = true
        endIf

        UI.InvokeInt("Console", "_global.Console.SetHistoryCharBufferSize", 100000)

        UI.SetFloat("Console", "_global.Console.ConsoleInstance._SearchInitialized", 69) ; Set as initialized
        
        if consoleOpen && consoleUtilInstalled
            Input.TapKey(Input.GetMappedKey("Console")) ; Close (but keep it open if console util not installed)
        endIf
    endIf

    ; Clear the console
    UI.SetString("Console", "_global.Console.ConsoleInstance.CommandHistory.text", "")

    ; Console command
    string command = "help \"" + query + "\""

    ; Run the command
    if consoleUtilInstalled ; Use ConsoleUtil if installed
        ; Run the command (in the background)
        ConsoleUtil.ExecuteCommand(command)

        ; Wait on the output to not be blank (or have more than just the command we write)
        while UI.GetString("Console", "_global.Console.ConsoleInstance.CommandHistory.text") == "" || UI.GetString("Console", "_global.Console.ConsoleInstance.CommandHistory.text") == command
            Utility.WaitMenuMode(0.01)
        endWhile
    else
        ; Open
        if ! consoleOpen
            Input.TapKey(Input.GetMappedKey("Console"))
            consoleOpen = true
        endIf

        ; Wait for it to be Shown
        while ! UI.GetBool("Console", "_global.Console.ConsoleInstance.Shown")
            Utility.WaitMenuMode(0.01)
        endWhile

        ;  The command to run
        UI.SetString("Console", "_global.Console.ConsoleInstance.CommandEntry.text", command)

        while UI.GetString("Console", "_global.Console.ConsoleInstance.CommandEntry.text") != command
            Utility.WaitMenuMode(0.01)
        endWhile

        ; Enter (Twice, just cuz)
        Input.TapKey(28)
        Input.TapKey(28)

        ; Just cuz.
        Utility.WaitMenuMode(0.01) 

        ; Close
        if consoleOpen
            Input.TapKey(Input.GetMappedKey("Console"))
        endIf

        ; Wait on the output to not be blank (or have more than just the command we write)
        while UI.GetString("Console", "_global.Console.ConsoleInstance.CommandHistory.text") == "" || UI.GetString("Console", "_global.Console.ConsoleInstance.CommandHistory.text") == command
            Utility.WaitMenuMode(0.01)
        endWhile
    endIf

    ; Remove this from the most recently run command list
    int commandHistoryLength = UI.GetInt("Console", "_global.Console.ConsoleInstance.Commands.length")
    UI.InvokeInt("Console", "_global.Console.ConsoleInstance.Commands.splice", commandHistoryLength - 1)

    return UI.GetString("Console", "_global.Console.ConsoleInstance.CommandHistory.text")
endFunction

; Search Skyrim
;
; Uses the Skyrim ~ console. The ~ console will actually pop open while the Search runs.
;
; You can optionally pass along a `category` name. The category names correspond to those you'll find
; when using the `help` command in the Skyrim console, e.g. to filter for just NPCs, use `NPC_`
;
; If you want to filter down your results further, provide an additional `filter`.
; Only results which include the provided text in their Name, EditorID, or FormID will be returned.
;
; This function returns an identifier representing the discovered test results.
;
; To read the individual test results, see `GetResultCategories()` `GetResultCategoryCount()` `GetNthResultInCategory()`
;
; ```
; int results = ConsoleConsoleSearch.Search("Hod")
;
; string[] foundCategories = ConsoleConsoleSearch.GetResultCategories(results)
;
; int categoryIndex = 0
; while categoryIndex < foundCategories.Length
;   string category = foundCategories[categoryIndex]
;
;   int countInCategory = ConsoleConsoleSearch.GetResultCategoryCount(results, category)
;   int i = 0
;   while i < countInCategory
;       int result = ConsoleConsoleSearch.GetNthResultInCategory(results, category, i)
;       
;       Debug.Trace("Result name: " + ConsoleConsoleSearch.GetResultName(result))
;       Debug.Trace("Result form ID: " + ConsoleConsoleSearch.GetResultFormID(result))
;       Debug.Trace("Result editor ID: " + ConsoleConsoleSearch.GetResultEditorID(result))
;
;       i += 1
;   endWhile
;
;   categoryIndex += 1
; endWhile
;
; ```
int function ExecuteSearch(string query, string category = "", string filter = "") global
    int results = JMap.object()
    string newline = StringUtil.AsChar(13) ; 10 is Line Feed, 13 is Carriage Return
    string text = Help(query)
    string[] lines = StringUtil.Split(text, newline)

    int i = 0
    while i < lines.Length
        string line = lines[i]
        int colon = StringUtil.Find(line, ":")
        if colon > -1
            int openParens = StringUtil.Find(line, "(")
            int closeParens = StringUtil.Find(line, ")")
            int openSingleQuote = StringUtil.Find(line, "'")
            if openParens && closeParens && openSingleQuote
                string type = StringUtil.Substring(line, 0, colon)
                if type != "usage" && type != "filters" && (! category || type == category)
                    string editorId = ""
                    if (openParens - colon - 3) > 0
                        editorId = StringUtil.Substring(line, colon + 2, openParens - colon - 3)
                    endIf
                    string formId = StringUtil.Substring(line, openParens + 1, closeParens - openParens - 1)
                    string name = StringUtil.Substring(line, openSingleQuote + 1, StringUtil.GetLength(line) - openSingleQuote - 2)
                    if ! filter || StringUtil.Find(name, filter) > -1 || StringUtil.Find(formId, filter) > -1 || StringUtil.Find(editorId, filter) > -1
                        int result = JMap.object()
                        if JMap.hasKey(results, type)
                            JArray.addObj(JMap.getObj(results, type), result)
                        else
                            int typeArray = JArray.object()
                            JArray.addObj(typeArray, result)
                            JMap.setObj(results, type, typeArray)
                        endIf
                        JMap.setStr(result, "name", name)
                        JMap.setStr(result, "editorID", editorId)
                        JMap.setStr(result, "formID", formId)
                    endIf
                endIf
            endIf
        endIf
        i += 1
    endWhile

    return results
endFunction

; Gets a full list of all of categories of discovered results.
; Provide the "`allResultsReference`" which is returned by the `Search()` function.
string[] function GetResultCategories(int allResultsReference) global
    return JMap.allKeysPArray(allResultsReference)
endFunction

; Gets the count of all results discovered in the specified category.
; Provide the "`allResultsReference`" which is returned by the `Search()` function.
int function GetResultCategoryCount(int allResultsReference, string category) global
    int categoryArray = JMap.getObj(allResultsReference, category)
    if categoryArray
        return JArray.count(categoryArray)
    else
        return 0
    endIf
endFunction

; Gets a reference to an individual search result in a specified category.
; Use `GetResultCategoryCount()` to get the full count of individual search results in the category,
; and then use `GetNthResultInCategory()` to get a result in that category using an array index.
; Provide the "`allResultsReference`" which is returned by the `Search()` function.
int function GetNthResultInCategory(int allResultsReference, string category, int index) global
    int categoryArray = JMap.getObj(allResultsReference, category)
    if categoryArray
        return JArray.getObj(categoryArray, index)
    else
        return 0
    endIf
endFunction

; Get the Name of this result.
; To get a result, see `GetNthResultInCategory`.
string function GetResultName(int individualResultReference) global
    return JMap.getStr(individualResultReference, "name")
endFunction

; Get the EditorID of this result.
; To get a result, see `GetNthResultInCategory`.
string function GetResultEditorID(int individualResultReference) global
    return JMap.getStr(individualResultReference, "editorID")
endFunction

; Get the FormID of this result.
; To get a result, see `GetNthResultInCategory`.
string function GetResultFormID(int individualResultReference) global
    return JMap.getStr(individualResultReference, "formID")
endFunction

; Stores the given result(s) in your upcoming save game file.
; Otherwise, the reference may stop working after a few seconds.
; Reference IDs are intended to be used only for a brief amount of time.
; Can be an individual result or full result set (like that returned by `Search`).
function SaveResult(int result) global
    JValue.retain(result)
endFunction

; Deleted the given result(s) from your upcoming save game file.
; Otherwise, the reference may stop working after a few seconds.
; Reference IDs are intended to be used only for a brief amount of time.
; Can be an individual result or full result set (like that returned by `Search`).
function DeleteResult(int result) global
    JValue.release(result)
endFunction

; Saves the given result(s) to file.
; Can be an individual result or full result set (like that returned by `Search`).
; The specified file path is relative to your Skyrim Special Edition folder.
function SaveResultToFile(int result, string filepath) global
    JValue.writeToFile(result, filepath)
endFunction

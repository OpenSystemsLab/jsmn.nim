import jsmn, marshal, tables

type
  Status = enum
    done, wontfix, inprogress

  Task = object
    id: int
    title: string
    done: Status
    notes: string
    tags: array[0..1, string]
    categories: seq[string]


var t1: Task
t1.id = 1
t1.title = "Blah blah"
t1.done = wontfix
t1.tags = ["test", "blah"]
t1.categories = @["works", "urgent"]


let js = $$t1

var tokens: array[32, JsmnToken]
let r = parseJson(js, tokens)
if r < 0:
  quit("Error: " & $r, QuitFailure)


var map = newTable[string, pointer]()

for n, v in fieldPairs(t1):
  map[n] = v

proc isKey(token: JsmnToken, json, key: string): bool =
  token.kind == JSMN_STRING and
  len(key) == (token.stop - token.start) and
  key == json[token.start..<token.stop]



for x in 1..r:
  var token = tokens[x]
  for (i = 1; i < r; i++):
    if (token, js, "id"):
      echo

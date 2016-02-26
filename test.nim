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
    user: User

  User = object
    name: string
    age: int

var
  u1: User
  t1: Task

u1.name = "John Doe"
u1.age = 32

t1.id = 1
t1.title = "Blah blah"
t1.done = wontfix
t1.tags = ["test", "blah"]
t1.categories = @["works", "urgent"]
t1.user = u1

template GET_KEY(token: ptr JsmnToken, json: string): expr =
  assert token.kind == JSMN_STRING
  json[token.start..<token.stop]

var
  i, j, k = 0
  count: int
  t, nxt: JsmnToken
  maps = newTable[string, JsmnToken](32)
  tokens: array[32, JsmnToken]

var js = $$t1
echo js
let r = parseJson(addr js, tokens)
if r < 0:
  quit("Error: " & $r, QuitFailure)

proc dumpObject(tokens: openarray[JsmnToken], map: TableRef[string, JsmnToken], size: int, i: var int) =
  if tokens[0].kind != JSMN_OBJECT:
    quit("Object expected", QuitFailure)

  var key: string
  while i < size:
    inc(i) # skip first token
    var t = tokens[i]
    if t.kind == JSMN_STRING:
      key = GET_KEY(addr t, js)
      echo key
     echo "[", i, "]\t", t
      nxt = tokens[i+1]

     case nxt.kind
     of JSMN_STRING:
       inc(i)
     of JSMN_PRIMITIVE:
       inc(i)
     of JSMN_ARRAY:
       inc(i, t.size)
     of JSMN_OBJECT:
       discard
     else:
       discard


dumpObject(tokens, maps, tokens[0].size, i)

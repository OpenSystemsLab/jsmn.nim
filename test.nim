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
  t, nxt: ptr JsmnToken
  maps = newTable[string, JsmnToken](32)
  tokens: array[32, JsmnToken]


var js = $$t1
echo js
let r = parseJson(addr js, tokens)
if r < 0:
  quit("Error: " & $r, QuitFailure)

while i < r:
  inc(i) # skip first token
  t = addr tokens[i]
  case t.kind
  of JSMN_STRING:
    echo "[", i, "]\t", t[]
    nxt = addr tokens[i+1]
#    inc(i)
#  of JSMN_ARRAY:
#    inc(i, t.size)
#  of JSMN_OBJECT:
#    inc(i, t.size*2)
  else:
    echo "[", i, "]\t", t[]

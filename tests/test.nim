import jsmn, marshal

type
  Status = enum
    done, wontfix, inprogress

  Task = object
    id: int
    title: string
    done: Status
    notes: string
    tags: array[0..1, string]
    user: User
    categories: seq[string]
    published: bool


  User = object
    name: string
    age: int

var
  u1: User
  t1, t2: Task

u1.name = "John Doe"
u1.age = 32

t1.id = 1
t1.title = "Blah blah"
t1.done = wontfix
t1.tags = ["test", "blah"]
t1.categories = @["works", "urgent"]
t1.user = u1
t1.published = false


var
  tokens: array[32, JsmnToken]

var js = $$t1
echo js
let r = parseJson(addr js, tokens)
if r < 0:
  quit("Error: " & $r, QuitFailure)

loadObject(t2, tokens, js)
echo $$t2

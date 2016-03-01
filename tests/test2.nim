import ../jsmn

type
  Student = object
    name: string
    age: int
    points: seq[int]
    friends: seq[Student]
let js = """{"name": "John", "age": 30, points: [], friends: []}"""

let tokens = parseJson(js)
#echo getString(tokens, js, "name")

var
  s1: Student
loadObject(s1, tokens, tokens.len, js)
echo s1

import ../jsmn

type
  Student = object
    name: string
    age: int
    points: seq[int]
    friends: seq[Student]
let js = """{"name": "John", "age": 30, "points": [], "friends": []}"""

let j = newJsmn(js)
#echo getString(tokens, tokens.len, js, "name")

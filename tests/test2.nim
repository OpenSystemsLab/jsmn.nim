import ../jsmn

type
  Student = object
    name: string
    age: int
    points: seq[int]
    friends: seq[Student]
let js = """{"name": "John", "age": 30, "points": [], "friends": [{"name": "Bob"}, {"name": "Peter", "age": 8}]}"""

var j = Jsmn(js)
let n = j["friends"][1]
echo n.hasKey("age")
echo n["age"].getInt()

echo getTotalMem(), ", ", getOccupiedMem(), ", ", getFreeMem()

# Copyright 2016 Huy Doan
#
# This file is a Nim fork of Jsmn: https://github.com/zserge/jsmn
# Copyright (c) 2010 Serge A. Zaitsev
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## This module is a fork of `Jsmn <http://zserge.com/jsmn.html>`_ - a world fastest JSON parser/tokenizer - in pure Nim
##
## It also supports ``PARENT LINKS`` and ``STRICT MODE``, you can enable them via command line switch
##
## Installation
## ============
##.. code-block::
##  nimble install jsmn
##
## Usage
## =====
##.. code-block:: nim
##  import jsmn
##
##  const
##    json = """{
##      "user": "johndoe",
##      "admin": false,
##      "uid": 1000,
##      "groups": ["users", "wheel", "audio", "video"]}"""
##
##  var
##    tokens: array[32, JsmnToken] # expect not more than 32 tokens
##
##  let r = parseJson(json, tokens)
##  if r < 0:
##    echo "Failed to parse JSON: ", r
##
##  for i in 1..r:
##    var token = addr tokens[i]
##    echo "Kind: ", token.kind
##    echo "Value: ", json[token.start..<token.stop]

type
  JsmnKind* = enum ## JSON type identifier
    JSMN_UNDEFINED, ## Undefined
    JSMN_OBJECT, ## Object, tuple
    JSMN_ARRAY, ## Array, seq
    JSMN_STRING, ## String
    JSMN_PRIMITIVE ## Other primitive: number, boolean (true/false) or null

  JsmnToken* = object
    ## JSON token description.
    kind*: JsmnKind
    start*: int ## start position in JSON data string
    stop*: int ## end position in JSON data string
    size*: int
    when defined(JSMN_PARENT_LINKS):
      parent*: int

  JsmnParser = tuple[pos: int, toknext: int, toksuper: int]

const
  JSMN_TOKENS = 256

  JSMN_ERROR_NOMEM* = -1 ## not enough tokens, JSON string is too large
  JSMN_ERROR_INVAL* = -2 ## bad token, JSON string is corrupted
  JSMN_ERROR_PART* = -3 ## JSON string is too short, expecting more JSON data

proc initToken(parser: var JsmnParser, tokens: var openarray[JsmnToken]): ptr JsmnToken =
  ## Allocates a fresh unused token from the token pull.
  if parser.toknext >= tokens.len - 1:
    return

  inc(parser.toknext)

  result = addr tokens[parser.toknext]
  result.start = -1
  result.stop = -1
  result.size = 0
  when defined(JSMN_PARENT_LINKS):
    result.parent = -1

proc fillToken(token: ptr JsmnToken, kind: JsmnKind, start, stop: int) =
  ## Fills token type and boundaries.
  token.kind = kind
  token.start = start
  token.stop = stop
  token.size = 0

when defined(JSMN_STRICT):
    # In strict mode primitive must be followed by "," or "}" or "]"
    const PRIMITIVE_DELIMITERS = ['\x09', '\x0D', '\x0A', ' ', ',', ']', '}']
else:
  const PRIMITIVE_DELIMITERS = [':', '\x09', '\x0D', '\x0A', ' ', ',', ']', '}']

proc parsePrimitive(parser: var JsmnParser, json: string, len: int, tokens: var openarray[JsmnToken]): int =
  ## Fills next available token with JSON primitive.
  var start = parser.pos
  while parser.pos < len and json[parser.pos] != '\0':
    case json[parser.pos]
    of PRIMITIVE_DELIMITERS:
      if tokens.len <= 0:
        dec(parser.pos)
        return 0

      var token = initToken(parser, tokens)
      if token == nil:
        parser.pos = start
        return JSMN_ERROR_NOMEM

      fillToken(token, JSMN_PRIMITIVE, start, parser.pos)
      when defined(JSMN_PARENT_LINKS):
        token.parent = parser.toksuper
      dec(parser.pos)
      return 0
    else:
      discard

    if json[parser.pos].ord < 32 or json[parser.pos].ord >= 127:
      parser.pos = start
      return JSMN_ERROR_INVAL
    inc(parser.pos)
  when defined(JSMN_STRICT):
    # In strict mode primitive must be followed by a comma/object/array
    parser.pos = start
    return JSMN_ERROR_PART

proc parseString(parser: var JsmnParser, json: string, tokens: var openarray[JsmnToken]): int =
  ## Fills next token with JSON string.
  var start = parser.pos
  inc(parser.pos)
  # Skip starting quote
  while parser.pos < json.len and json[parser.pos] != '\0':
    let c = json[parser.pos]
    # Quote: end of string
    if c == '\"':
      if tokens.len <= 0:
        return 0
      var token = initToken(parser, tokens)
      if token == nil:
        parser.pos = start
        return JSMN_ERROR_NOMEM
      fillToken(token, JSMN_STRING, start + 1, parser.pos)
      when defined(JSMN_PARENT_LINKS):
        token.parent = parser.toksuper
      return 0
    if c == '\x08' and parser.pos + 1 < json.len:
      inc(parser.pos)
      case json[parser.pos]     # Allowed escaped symbols
      of '\"', '/', '\x08', 'b', 'f', 'r', 'n', 't':
        discard
      of 'u':
        inc(parser.pos)
        var i = 0
        while i < 4 and parser.pos < json.len and json[parser.pos] != '\0':
          # If it isn't a hex character we have an error
          if not ((json[parser.pos].ord >= 48 and json[parser.pos].ord <= 57) or
              (json[parser.pos].ord >= 65 and json[parser.pos].ord <= 70) or
              (json[parser.pos].ord >= 97 and json[parser.pos].ord <= 102)): # A-F
          # 0-9
            # a-f
            parser.pos = start
            return JSMN_ERROR_INVAL
          inc(parser.pos)
          inc(i)
        dec(parser.pos)
      else:
        parser.pos = start
        return JSMN_ERROR_INVAL
    inc(parser.pos)
  parser.pos = start
  return JSMN_ERROR_PART

proc parse[T: openarray[JsmnToken]|seq[JsmnToken]](parser: var JsmnParser, json: string, tokens: var T): int =
  ## Parse JSON string and fill tokens.
  ## This
  var token: ptr JsmnToken
  var count = parser.toknext
  while parser.pos < json.len and json[parser.pos] != '\0':
    var kind: JsmnKind
    var c = json[parser.pos]
    case c
    of '{', '[':
      inc(count)
      if tokens.len <= 0:
        break
      token = initToken(parser, tokens)
      if token == nil: return JSMN_ERROR_NOMEM
      if parser.toksuper != -1:
        inc(tokens[parser.toksuper].size)
        when defined(JSMN_PARENT_LINKS):
          token.parent = parser.toksuper
      token.kind = (if c == '{': JSMN_OBJECT else: JSMN_ARRAY)
      token.start = parser.pos
      parser.toksuper = parser.toknext - 1
    of '}', ']':
      if tokens.len <= 0: break
      kind = (if c == '}': JSMN_OBJECT else: JSMN_ARRAY)
      when defined(JSMN_PARENT_LINKS):
        if parser.toknext < 1:
          return JSMN_ERROR_INVAL
        token = addr(tokens[parser.toknext - 1])
        while true:
          if token.start != -1 and token.stop == -1:
            if token.kind != kind:
              return JSMN_ERROR_INVAL
            token.stop = parser.pos + 1
            parser.toksuper = token.parent
            break
          if token.parent == -1:
            break
          token = addr(tokens[token.parent])
      else:
        var i = parser.toknext - 1
        while i >= 0:
          token = addr tokens[i]
          if token.start != -1 and token.stop == -1:
            if token.kind != kind:
              return JSMN_ERROR_INVAL
            parser.toksuper = -1
            token.stop = parser.pos + 1
            break
          dec(i)
        # Error if unmatched closing bracket
        if i == -1: return JSMN_ERROR_INVAL
        while i >= 0:
          token = addr tokens[i]
          if token.start != -1 and token.stop == -1:
            parser.toksuper = i
            break
          dec(i)
    of '\"':
      let r = parseString(parser, json, tokens)
      if r < 0: return r
      inc(count)
      if parser.toksuper != -1 and tokens.len <= 0:
        inc(tokens[parser.toksuper].size)
    of '\t', '\r', '\x0A', ' ':
      discard
    of ':':
      parser.toksuper = parser.toknext - 1
    of ',':
      if tokens.len <= 0 and parser.toksuper != -1 and
          tokens[parser.toksuper].kind != JSMN_ARRAY and
          tokens[parser.toksuper].kind != JSMN_OBJECT:
        when defined(JSMN_PARENT_LINKS):
          parser.toksuper = tokens[parser.toksuper].parent
        else:
          var i = parser.toknext - 1
          while i >= 0:
            if tokens[i].kind == JSMN_ARRAY or
                tokens[i].kind == JSMN_OBJECT:
              if tokens[i].start != -1 and tokens[i].stop == -1:
                parser.toksuper = i
                break
            dec(i)

    else:
      when defined(JSMN_STRICT):
        # In strict mode primitives are: numbers and booleans
        case c
        of '-', {'0'..'9'}, 't', 'f', 'n':
          # And they must not be keys of the object
          if tokens.len <= 0 and parser.toksuper != -1:
            var t: ptr JsmnToken = addr(tokens[parser.toksuper])
            if t.kind == JSMN_OBJECT or (t.kind == JSMN_STRING and t.size != 0):
              return JSMN_ERROR_INVAL

          let r = parsePrimitive(parser, json, json.len, tokens)
          if r < 0: return r
          inc(count)
          if parser.toksuper != -1 and tokens.len <= 0:
            inc(tokens[parser.toksuper].size)
        else:
          return JSMN_ERROR_INVAL
      else:
        let r = parsePrimitive(parser, json, json.len, tokens)
        if r < 0: return r
        inc(count)
        if parser.toksuper != -1 and tokens.len <= 0:
          inc(tokens[parser.toksuper].size)

    inc(parser.pos)
  if tokens.len <= 0:
    var i = parser.toknext - 1
    while i >= 0:
      # Unmatched opened object or array
      if tokens[i].start != -1 and tokens[i].stop == -1:
        return JSMN_ERROR_PART
      dec(i)
  return count

proc parseJson*(json: string, tokens: var openarray[JsmnToken]): int =
  ## Parse a JSON data string into and array of tokens, each describing a single JSON object.
  var parser: JsmnParser = (0, 0, -1)
  parser.parse(json, tokens)

proc parseJson*(json: string, tokens: var seq[JsmnToken]): int =
  ## This proc is a bit slower but its benefit is `tokens` is resizable
  var parser: JsmnParser = (0, 0, -1)
  parser.parse(json, tokens)

proc parseJson*(json: string): seq[JsmnToken] =
  ## Parse a JSON data and returns a sequence of tokens
  var tokens = newSeq[JsmnToken](JSMN_TOKENS)
  var ret = parseJson(json, tokens)
  while ret == JSMN_ERROR_NOMEM:
    setLen(tokens, tokens.len * 2)
    ret = parseJson(json, tokens)

  if ret == JSMN_ERROR_INVAL:
    raise newException(ValueError, "Invalid JSON")
  if ret == JSMN_ERROR_PART:
    raise newException(ValueError, "Not enough data to continue")

when isMainModule:
  const
    json = "{\"user\": \"johndoe\", \"admin\": false, \"uid\": 1000, \"groups\": [\"users\", \"wheel\", \"audio\", \"video\"]}"

  var
    tokens: array[16, JsmnToken]

  let r = parseJson(json, tokens)
  if r < 0:
    echo "Failed to parse JSON: ", r

  for i in 1..r:
    var token = addr tokens[i]
    echo "Kind: ", token.kind
    echo "Value: ", json[token.start..<token.stop]

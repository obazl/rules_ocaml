# source: https://groups.google.com/u/1/g/bazel-discuss/c/QsuB29hxlSA
def join_strings(strings):
  '''Joins a sequence of objects as strings, with select statements that return
  strings handled correctly. This has O(N^2) performance, so don't use it for
  building up large results.

  This is mostly equivalent to " ".join(strings), except for handling select
  statements correctly.'''
  result = ''
  first = True
  for string in strings:
    if first:
      first = False
    else:
      result += ' '
    if type(string) == 'select':
      result += string
    else:
      result += str(string)
  return result

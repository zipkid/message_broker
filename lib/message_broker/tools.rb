# encoding: utf-8

def deep_copy(o)
  Marshal.load(Marshal.dump(o))
end

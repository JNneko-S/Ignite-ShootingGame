"""Small helpers to edit Godot text resources (.tres / .tscn) in place."""
import re

class Tres:
    def __init__(self, path):
        self.path = path
        self.s = open(path, encoding='utf-8').read()

    def save(self):
        open(self.path, 'w', encoding='utf-8', newline='\n').write(self.s)

    def has_id(self, rid):
        return re.search(r'id="%s"' % re.escape(rid), self.s) is not None

    def ext(self, rtype, path, rid):
        """Add an ext_resource (if missing) and return its id."""
        m = re.search(r'\[ext_resource [^\]]*path="%s" id="([^"]+)"\]' % re.escape(path), self.s)
        if m:
            return m.group(1)
        line = '[ext_resource type="%s" path="%s" id="%s"]\n' % (rtype, path, rid)
        last = list(re.finditer(r'^\[ext_resource [^\n]*\n', self.s, re.M))[-1]
        self.s = self.s[:last.end()] + line + self.s[last.end():]
        return rid

    def sub(self, rid, body, before='[resource]'):
        """Add (or replace) a sub_resource block before `before` (a header line that exists)."""
        block = '[sub_resource type="Resource" id="%s"]\n%s\n\n' % (rid, body.strip('\n'))
        m = re.search(r'\[sub_resource type="Resource" id="%s"\]\n.*?(?=\n\[|\Z)' % re.escape(rid), self.s, re.S)
        if m:
            self.s = self.s[:m.start()] + block.rstrip('\n') + self.s[m.end():]
            return
        i = self.s.find(before)
        assert i >= 0, before
        self.s = self.s[:i] + block + self.s[i:]

    def append_array(self, key, item, section_marker='[resource]'):
        """Append item to `key = Array[...]([ ... ])` inside the section that starts at section_marker."""
        i = self.s.find(section_marker)
        assert i >= 0, section_marker
        m = re.compile(r'^%s = (Array\[[^\]]+\]\(\[)(.*?)(\]\))$' % re.escape(key), re.M).search(self.s, i)
        assert m, key
        inner = m.group(2)
        if item in inner:
            return
        inner = (inner + ', ' + item) if inner.strip() else item
        self.s = self.s[:m.start(2)] + inner + self.s[m.end(2):]

    def set_in_block(self, header, key, value):
        """Set `key = value` inside the block whose header line is `header`."""
        i = self.s.find(header)
        assert i >= 0, header
        j = self.s.find('\n[', i + 1)
        j = len(self.s) if j < 0 else j
        block = self.s[i:j]
        pat = re.compile(r'^%s = .*$' % re.escape(key), re.M)
        if pat.search(block):
            block = pat.sub('%s = %s' % (key, value), block, count=1)
        else:
            block = block.rstrip('\n') + '\n%s = %s\n' % (key, value)
            if j < len(self.s):
                block += '\n'
        self.s = self.s[:i] + block + self.s[j:]

    def get_in_block(self, header, key):
        i = self.s.find(header)
        assert i >= 0, header
        j = self.s.find('\n[', i + 1)
        block = self.s[i:(len(self.s) if j < 0 else j)]
        m = re.search(r'^%s = (.*)$' % re.escape(key), block, re.M)
        return m.group(1) if m else None

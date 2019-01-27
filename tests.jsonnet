#!/usr/bin/env jsonnet

local mab = import 'mab.libsonnet';

local tests = {
  local test(r, v) =
    if r == v then true else error '\nreturned: ' + r + '\nexpected: ' + v,
  match: [
    {
      r: mab.match(t.p, t.d),
      v: test(self.r, t.v)
    }
    for t in import 'match.json'
  ],
  bind: [
    {
      r: mab.bind(t.p, t.e),
      v: test(self.r, t.v)
    }
    for t in import 'bind.json'
  ],
  matchAndBind: [
    {
      r: mab.matchAndBind(t.m, t.b, t.d),
      v: test(self.r, t.v)
    }
    for t in import 'matchAndBind.json'
  ],
};

[
  tests.match,
  tests.bind,
  tests.matchAndBind,
]

// Local Variables:
// indent-tabs-mode: nil
// End:

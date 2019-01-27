#!/usr/bin/env jsonnet

local trace = import 'trace.libsonnet';

local mab = {

  local id(x) = x,
  local indexes(x) =
    local t = std.type(x);
    if t == 'object' then std.objectFields(x)
    else if t == 'array' then std.makeArray(std.length(x), id)
    else error 'indexes parameter must be an array or an object, got ' + t,
  local isScalar(x) = std.isString(x) || std.isNumber(x) || std.isBoolean(x),

  local META = '_',
  local LOOP = META + 'loop' + META,
  local MATCH = 'm',
  local OK = { [MATCH]: true },
  local fail(e) = e + { [MATCH]: false },
  local isFailed(e) = e[MATCH] == false,
  local isVar(p) = std.isString(p) && std.startsWith(p, META),
  local isConstant(p) = !isVar(p),
  local constantKeys(o) = std.filter(isConstant, std.objectFields(o)),
  local varKeys(o) = std.filter(isVar, std.objectFields(o)),
  local isDefinedVar(x, e) = std.objectHas(e, x),
  local isArrayLoop(x) = std.isObject(x) && std.length(x) == 1 && std.objectFields(x)[0] == META,
  local isBindArrayLoop(x) = 
    if std.isObject(x) && std.length(x) == 1 then
      local k = std.objectFields(x)[0];
      if std.startsWith(k, META) && std.endsWith(k, META) then true else false
   else false,
  local bindArrayLoopVar(x) =
    local k = std.objectFields(x)[0];
    std.substr(k, 0, std.length(k) - 1),
  local bindArrayLoopPattern(x) = x[std.objectFields(x)[0]],

  // trace

  local traces = {
    none: [],
    one: [ 'matchVarObjects' ],
    two: [ 'matchObjects', 'matchVarObjects' ],
    some: [ 'matchAndBind', 'matchTop', 'bind' ],
    match: [ 'matchTop', 'matchVar', 'matchObjects', 'matchVarObjects', 'matchArrays', 'matchConstantArrays', 'matchVarArray' ],
    bind: [ 'bind', 'bindConstantArrays', 'bindVarArrays', 'bindConstantObjects', 'bindVarObjects', 'bindLoop' ],
    all: [ f for f in std.objectFieldsAll($) if std.isFunction($[f]) == true ],
  },
  local traced = { [f]: null for f in std.set(traces.none) },

  match(p, d, e = OK):: trace(traced, self.match_, [ 'match', 'p', 'd', 'e'], [p, d, e]),
  matchTop(p, d, e):: trace(traced, self.matchTop_, [ 'matchTop', 'p', 'd', 'e'], [p, d, e]),
  matchVar(v, d, e):: trace(traced, self.matchVar_, [ 'matchVar', 'v', 'd', 'e'], [v, d, e]),
  matchObjects(p, d, e):: trace(traced, self.matchObjects_, [ 'matchObjects', 'p', 'd', 'e'], [p, d, e]),
  matchConstantObjects(p, d, e):: trace(traced, self.matchConstantObjects_, [ 'matchConstantObjects', 'p', 'd', 'e'], [p, d, e]),
  matchVarObjects(pat, dat, env):: trace(traced, self.matchVarObjects_, [ 'matchVarObjects', 'pat', 'dat', 'env'], [pat, dat, env]),
  matchArrays(p, d, e):: trace(traced, self.matchArrays_, [ 'matchArrays', 'p', 'd', 'e'], [p, d, e]),
  matchConstantArrays(p, d, e):: trace(traced, self.matchConstantArrays_, [ 'matchConstantArrays', 'p', 'd', 'e'], [p, d, e]),
  matchVarArrays(p, d, e):: trace(traced, self.matchVarArrays_, [ 'matchVarArrays', 'p', 'd', 'e'], [p, d, e]),
  cleanEnv(e):: trace(traced, self.cleanEnv_, [ 'cleanEnv', 'e'], [e]),
 
  bind(p, e):: trace(traced, self.bind_, [ 'bind', 'p', 'e'], [p, e]),
  bindConstantArray(p, e):: trace(traced, self.bindConstantArray_, [ 'bindConstantArray', 'p', 'e'], [p, e]),
  bindVarArray(p, v, e):: trace(traced, self.bindVarArray_, [ 'bindVarArray', 'p', 'v', 'e'], [p, v, e]),
  bindConstantObject(p, e):: trace(traced, self.bindConstantObject_, [ 'bindConstantObject', 'p', 'e'], [p, e]),
  bindVarObject(p, e):: trace(traced, self.bindVarObject_, [ 'bindVarObject', 'p', 'e'], [p, e]),
  bindLoop(v, e):: trace(traced, self.bindLoop_, [ 'bindLoop', 'v', 'e'], [v, e]),

  matchAndBind(m, b, d, e = OK):: trace(traced, self.matchAndBind_, [ 'mab', 'm', 'b', 'd', 'e'], [m, b, d, e]),

  // match

  match_(p, d, e = OK)::
    local r = self.matchTop(p, d, e);
    self.cleanEnv(self.matchTop(p, d, e)) + { [MATCH]: r.m },

  cleanEnv_(e)::
    if isScalar(e) then e
    else if std.isArray(e) then std.map(self.cleanEnv, e)
    else if std.isObject(e) then std.foldl(function(o, k) o + if k != MATCH  then { [k]: $.cleanEnv(e[k]) } else {}, std.objectFields(e), {}),

  matchTop_(p, d, e)::
    if isFailed(e) then e
    else if isVar(p) then self.matchVar(p, d, e)
    else if std.type(p) != std.type(d) then fail(e)
    else if isScalar(p) then e + { [MATCH]: p == d }
    else if std.isObject(p) then self.matchObjects(p, d, e)
    else if std.isArray(p) then self.matchArrays(p, d, e)
    else fail(e),

  matchVar_(v, d, e)::
    if isDefinedVar(v, e) then self.matchTop(e[v], d, e) else e + { [v]: d },

  matchObjects_(p, d, e)::
    if std.filter(isVar, std.objectFields(p)) == [] then self.matchConstantObjects(p, d, e)
    else self.matchVarObjects(p, d, e),

  matchConstantObjects_(p, d, e)::
    if std.objectFields(p) != std.objectFields(d) then fail(e)
    else std.foldl(function(e, k) e + self.matchTop(p[k], d[k], e), indexes(p), e),

  matchVarObjects_(pat, dat, env)::
    local constantKeys(o) = std.filter(isConstant, std.objectFields(o));
    local varKeys(o) = std.filter(isVar, std.objectFields(o));
    local datKeys = std.objectFields(dat);
    local constantPatKeys = constantKeys(pat);
    local comonnConstantKeys = std.setInter(std.set(constantPatKeys), std.set(datKeys));
    local dataKeysOnly = std.setDiff(std.set(datKeys), std.set(comonnConstantKeys));
    local varPatKey = varKeys(pat)[0];
    local comonnConstantMatched = 
       std.foldl(function(e, k) e + self.matchTop(pat[k], dat[k], e), comonnConstantKeys, env);
    local loopEnv =
      std.map(
        function(k) self.matchTop(pat[varPatKey], dat[k], env + { [varPatKey]: k }),
        dataKeysOnly);
    local loop = self.matchTop(LOOP, loopEnv, env);
    local ret = comonnConstantMatched + loop;
    if constantPatKeys != comonnConstantKeys || isFailed(comonnConstantMatched) || isFailed(loop)
      then fail(ret) else ret,

  matchArrays_(p, d, e)::
    // local isArrayLoop(x) = std.isObject(x) && std.length(x) == 1 && std.objectFields(x)[0] == META;
    if isArrayLoop(p[0]) then self.matchTop(LOOP, self.matchVarArrays(p[0][META], d, e), e)
    else self.matchConstantArrays(p, d, e),

  _matchArrays_(p, d, e)::
    local isArrayLoop(x) = std.isObject(x) && std.length(x) == 1 && std.objectFields(x)[0] == META;
    if isArrayLoop(p[0]) then self.matchTop(LOOP, self.matchVarArrays(p[0][META], d, e), e)
    else self.matchConstantArrays(p, d, e),

  matchConstantArrays_(p, d, e)::
    local l = std.length(p);
    if l != std.length(d) then fail(e)
    else if l == 0 then e
    else std.foldl(function(e, k) e + self.matchTop(p[k], d[k], e), indexes(p), e),

  matchVarArrays_(p, d, e)::
    std.map(function(i) self.matchTop(p, i, e), d),

  // bind

  bind_(p, e):: 
    if isScalar(p) then
      if isVar(p) then e[p] else p
    else if std.isArray(p) then
      if isBindArrayLoop(p[0]) then
        // self.bindVarArray(bindArrayLoopVar(p[0]), e)
        self.bindVarArray(bindArrayLoopPattern(p[0]), bindArrayLoopVar(p[0]), e)
      else self.bindConstantArray(p, e)
    else if std.isObject(p) then
      if std.filter(isVar, std.objectFields(p)) == [] then self.bindConstantObject(p, e)
      else self.bindVarObject(p, e)
    else error 1,

  _bind_(p, e):: 
    if isScalar(p) then
      if isVar(p) then e[p] else p
    else if std.isArray(p) then
      if isVar(p[0]) then self.bindVarArray(p, e)
      else self.bindConstantArray(p, e)
    else if std.isObject(p) then
      if std.filter(isVar, std.objectFields(p)) == [] then self.bindConstantObject(p, e)
      else self.bindVarObject(p, e)
    else error 1,

  bindConstantArray_(p, e):: std.map(function(i) self.bind(i, e), p),

  bindVarArray_(p, v, e)::
    [
      self.bind(p, ne) for ne in self.bindLoop(v, e)
    ],

  _bindVarArray_(p, e):: [ self.bind(p[0], i) for i in e[LOOP] ],

  bindConstantObject_(p, e):: std.mapWithKey(function(_, v) self.bind(v, e), p),

  bindLoop_(v, e)::
    local l = LOOP;
    if std.isArray(e) then std.map(function(a) self.bindLoop(v, a), e)
    else if isDefinedVar(l, e) then std.foldl(function(a, e) a + e, self.bindLoop(v, e[l]), [])
    else if isDefinedVar(v, e) then [e],

  bindVarObject_(p, e)::
    local constantPatKeys = constantKeys(p);
    local varPatKey = varKeys(p)[0];
    {
      [ne[varPatKey]]: $.bind(p[varPatKey], ne) for se in $.bindLoop(varPatKey, e) for ne in [e + se]
    }, // + self.bindConstantObject(constantPatKeys, e),

  // matchAndBind

  matchAndBind_(m, b, d, e = OK)::
    self.bind(b, self.matchTop(m, d, e)),
};

mab

// Local Variables:
// indent-tabs-mode: nil
// End:


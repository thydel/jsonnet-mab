#!/usr/bin/env jsonnet

local trace(traced, f, t, l) =
    local name = t[0];
    local isTraced = std.objectHas(traced, name);
    local s(n) = if isTraced then std.trace('' + name + '(' + t[n] + ') ' + l[n - 1], l[n - 1]) else l[n -1];
    local apply0(f, l) = f();
    local apply1(f, l) = f(s(1));
    local apply2(f, l) = f(s(1), s(2));
    local apply3(f, l) = f(s(1), s(2), s(3));
    local apply4(f, l) = f(s(1), s(2), s(3), s(4));
    local apply5(f, l) = f(s(1), s(2), s(3), s(4), s(5));
    local applys = [ apply0, apply1, apply2, apply3, apply4, apply5 ];
    local ret = applys[std.length(l)](f, l) tailstrict;
    if isTraced then std.trace('' + name + ' = ' + ret, ret) else ret;

trace

// Local Variables:
// indent-tabs-mode: nil
// End:

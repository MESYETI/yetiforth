module yf.util;

import std.string;
import core.stdc.stdlib;

char* ToCString(string str) {
	char* ret = cast(char*) malloc(str.length + 1);

	foreach (i, ref ch ; str) {
		ret[i] = ch;
	}

	ret[str.length] = 0;

	return ret;
}

string ToDString(char* str) {
	return str.fromStringz().dup;
}

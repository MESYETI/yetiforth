module yf.app;

import std.file;
import std.stdio;
import yf.builtin;
import yf.environment;

int main(string[] args) {
	auto env = new Environment();
	AddBuiltins(env);

	if (args.length == 1) {
		writefln("Usage: %s FILE", args[0]);
	}
	else {
		env.CompileFile("kernel.fs");
		env.CompileFile(args[1]);
		env.EndCompile();

		try {
			env.Run();
		}
		catch (ProgramQuit) {
			return 0;
		}
	}

	return 0;
}

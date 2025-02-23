module yf.environment;

import std.file;
import std.stdio;
import std.format;
import std.algorithm;
import core.stdc.stdlib : exit;

alias InstFunc = void function(Environment, Inst*);

struct Inst {
	union {
		string callString;
		ulong  callInt;
	}

	InstFunc func;

	this(string pcallString, InstFunc pfunc) {
		callString = pcallString;
		func       = pfunc;
	}

	this(ulong pcallInt, InstFunc pfunc) {
		callInt = pcallInt;
		func    = pfunc;
	}
}

struct Word {
	Inst[] compile;
	Inst[] run;

	static Word Interpret(InstFunc func, string callString = "") {
		return Word([], [Inst(callString, func)]);
	}

	static Word Compile(InstFunc func) {
		return Word([Inst(0, func)], []);
	}

	static Word Both(InstFunc func) {
		return Word([Inst(0, func)], [Inst(0, func)]);
	}
}

class EnvironmentError : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class ProgramQuit : Exception {
	this() {
		super("", "", 0);
	}
}

enum RunMode {
	Compile,
	Run
}

class Environment {
	Word[string] words;
	string       source;
	Inst[]       compiled;
	ulong[]      dataStack;
	ulong[]      returnStack;
	size_t       ip;
	RunMode      mode;

	this() {
		
	}

	ulong TopData() {
		if (dataStack.length == 0) {
			throw new EnvironmentError("Data stack underflow");
		}

		return dataStack[$ - 1];
	}

	ulong PopData() {
		auto res = TopData();
		dataStack = dataStack[0 .. $ - 1];
		return res;
	}

	ulong PopReturn() {
		if (returnStack.length == 0) {
			throw new EnvironmentError("Return stack underflow");
		}

		auto res    = returnStack[$ - 1];
		returnStack = returnStack[0 .. $ - 1];
		return res;
	}

	void RunInst(Inst* inst) {
		inst.func(this, inst);
	}

	Word GetWord(string word) {
		if (word !in words) {
			throw new EnvironmentError(format("Word '%s' doesn't exist", word));
		}

		return words[word];
	}

	void Compile() {
		auto word = GetWord("compile");

		foreach (ref inst ; word.compile) {
			inst.func(this, &inst);
		}
	}

	void EndCompile() {
		compiled ~= words["exit"].run;
	}

	void Run() {
		mode = RunMode.Run;
		ip   = 0;

		while (true) {
			Inst* inst = &compiled[ip];
			++ ip;

			inst.func(this, inst);
		}
	}

	void CompileFile(string path) {
		try {
			source = readText(path);
		}
		catch (FileException e) {
			stderr.writefln("%s", e.msg);
			exit(1);
		}

		Compile();
		source = "";
	}
}

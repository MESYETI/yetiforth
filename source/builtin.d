module yf.builtin;

import std.uni;
import std.conv;
import std.stdio;
import std.string;
import std.algorithm;
import core.stdc.stdlib : free, exit;
import yf.util;
import yf.environment;

// util
private string GetAndFree(Environment env) {
	auto ptr = cast(char*) env.PopData();
	auto ret = ptr.ToDString();
	free(ptr);
	return ret;
}

// word defs
private void NextWord(Environment env, Inst* inst) {
	string res;

	if (env.source.canFind!isWhite()) {
		size_t index = env.source.countUntil!isWhite();
		res          = env.source[0 .. index];
		env.source   = env.source[index .. $].strip();
	}
	else {
		res = env.source.strip();
		env.source = "";
	}

	env.dataStack ~= cast(ulong) res.ToCString();
}

private void RunWordDef(Environment env, Inst* inst) {
	auto word = env.GetWord(inst.callString);

	foreach (ref inst2 ; word.run) {
		inst2.func(env, &inst2);
	}
}

private void PushInt(Environment env, Inst* inst) {
	env.dataStack ~= inst.callInt;
}

private void Exit(Environment env, Inst* inst) {
	throw new ProgramQuit();
}

private void Compile(Environment env, Inst* inst) {
	env.mode = RunMode.Compile;

	while (env.source.strip() != "") {
		NextWord(env, null); // OK because `NextWord` does not use `inst`
		auto token = GetAndFree(env);

		if (env.mode == RunMode.Compile) {
			if (token.isNumeric()) {
				env.compiled ~= Inst(parse!ulong(token), &PushInt);
			}
			else {
				auto word = env.GetWord(token);

				foreach (ref inst2 ; word.compile) {
					inst2.func(env, &inst2);
				}

				env.compiled ~= word.run;
			}
		}
		else {
			if (token.isNumeric()) {
				env.dataStack ~= parse!ulong(token);
			}
			else {
				auto word = env.GetWord(token);

				foreach (ref inst2 ; word.run) {
					inst2.func(env, &inst2);
				}
			}
		}
	}
}

private void PrintInt(Environment env, Inst* inst) {
	writef("%d", env.PopData());
}

private void Emit(Environment env, Inst* inst) {
	writef("%c", cast(char) env.PopData());
}

private void Jump(Environment env, Inst* inst) {
	env.ip = inst.callInt;
}

private void Call(Environment env, Inst* inst) {
	env.returnStack ~= env.ip;
	env.ip           = inst.callInt;
}

private void Return(Environment env, Inst* inst) {
	env.ip = env.PopReturn();
}

private void BeginWord(Environment env, Inst* inst) {
	NextWord(env, null);
	auto wordName = GetAndFree(env);

	if (wordName in env.words) {
		// i think other forths allow you to make multiple words with the same name
		// but i don't really like that
		throw new EnvironmentError("Cannot redefine word '%s'", wordName);
	}

	// jump to end of word definition
	env.compiled ~= Inst(0, &Jump);

	// push address of last instruction
	env.dataStack ~= env.compiled.length - 1;

	// create word def
	env.words[wordName] = Word([], [Inst(env.compiled.length, &Call)]);
}

private void EndWord(Environment env, Inst* inst) {
	env.compiled ~= Inst(0, &Return);

	// get jump instruction address
	size_t index = env.PopData();
	env.compiled[index].callInt = env.compiled.length;
}

private void BeginImmWord(Environment env, Inst* inst) {
	NextWord(env, null);
	auto wordName = GetAndFree(env);

	if (wordName in env.words) {
		// i think other forths allow you to make multiple words with the same name
		// but i don't really like that
		throw new EnvironmentError("Cannot redefine word '%s'", wordName);
	}

	// jump to end of word definition
	env.compiled ~= Inst(0, &Jump);

	// push address of last instruction
	env.dataStack ~= env.compiled.length - 1;

	// push word name
	env.dataStack ~= cast(ulong) wordName.ToCString();
}

private void EndImmWord(Environment env, Inst* inst) {
	auto  wordName = GetAndFree(env);
	ulong defStart = env.TopData() + 1;

	Word word;

	// kinda spaghetti
	for (ulong i = defStart; i < env.compiled.length; ++ i) {
		word.compile ~= env.compiled[i];
	}

	env.compiled = env.compiled[0 .. defStart];

	word.run ~= Inst(env.compiled.length, &Call);

	env.words[wordName] = word;
}

private void ModeCompile(Environment env, Inst* inst) {
	env.mode = RunMode.Compile;
}

private void ModeInterpret(Environment env, Inst* inst) {
	env.mode = RunMode.Run;
}

private void String(Environment env, Inst* inst) {
	string res;

	while (true) {
		NextWord(env, null);
		auto token = GetAndFree(env);

		res ~= token ~ ' ';

		if (token[$ - 1] == '"') {
			res = res[0 .. $ - 2];
			break;
		}
	}

	env.compiled ~= Inst(cast(ulong) res.ToCString(), &PushInt);
}

private void Free(Environment env, Inst* inst) {
	free(cast(void*) env.PopData());
}

private void Dup(Environment env, Inst* inst) {
	if (env.dataStack.length == 0) {
		throw new EnvironmentError("Data stack underflow");
	}

	env.dataStack ~= env.dataStack[$ - 1];
}

private void Drop(Environment env, Inst* inst) {
	env.PopData();
}

private void Type(Environment env, Inst* inst) {
	writef("%s", (cast(char*) env.PopData()).fromStringz());
}

private void SaveComp(Environment env, Inst* inst) {
	env.compiled ~= Inst(env.PopData(), &PushInt);
}

void AddBuiltins(Environment env) {
	env.words["next_word"]  = Word.Compile(&NextWord);
	env.words["exit"]       = Word.Interpret(&Exit);
	env.words["compile"]    = Word.Compile(&Compile);
	env.words["emit"]       = Word.Interpret(&Emit);
	env.words["."]          = Word.Interpret(&PrintInt);
	env.words["return"]     = Word.Interpret(&Return);
	env.words[":"]          = Word.Compile(&BeginWord);
	env.words[";"]          = Word.Compile(&EndWord);
	env.words["::"]         = Word.Compile(&BeginImmWord);
	env.words[";;"]         = Word.Compile(&EndImmWord);
	env.words["#compile"]   = Word.Interpret(&ModeCompile);
	env.words["#interpret"] = Word.Compile(&ModeInterpret);
	env.words["s\""]        = Word.Compile(&String);
	env.words["free"]       = Word.Interpret(&Free);
	env.words["dup"]        = Word.Interpret(&Dup);
	env.words["drop"]       = Word.Interpret(&Drop);
	env.words["type"]       = Word.Interpret(&Type);
	env.words["save_comp"]  = Word.Compile(&SaveComp);
}

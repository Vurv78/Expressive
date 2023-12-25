# Expressive [![Linter Badge](https://github.com/Vurv78/Expressive/workflows/Linter/badge.svg)](https://github.com/Vurv78/Expressive/actions) [![License](https://img.shields.io/github/license/Vurv78/Expressive?color=red&include_prereleases)](https://github.com/Vurv78/Expressive/blob/master/LICENSE) [![Expressive Discord](https://img.shields.io/discord/936811504706134036?label=Discord&logo=discord&logoColor=ffffff&labelColor=7289DA&color=2c2f33)](https://discord.gg/u6eQPcZv4y) [![Website](https://img.shields.io/website?down_message=Offline&label=Try%20Me%21&up_color=Blue&up_message=Online&url=https%3A%2F%2Fvurv78.github.io%2FExpressive%2Fweb%2Findex.html)](https://vurv78.github.io/Expressive/web/index.html)
> Expression, but it's Typescript with extras

Expressive is the hopeful final solution to the Expression programming languages. It was originally a fork of Expression3, but has become a full rewrite. It is modeled after [Typescript](https://www.typescriptlang.org).

## Note
This is a work in progress. Adding this to the server may be dangerous.
And yes this is codenamed Expression4.

*This could potentially give players access to serverside lua. Yes. It's that bad.*

## Differences from E2
Practically everything.
There are classes, you can finally make lowercase variables, lambdas, and whatnot.
Everything is neatly in libraries, like ``holograms.create``

<!-- TODO List of stuff here -->

## Example Code

```ts
// You can create lowercased variables now.
// 'var' creates a global variable. It does not follow javascript/ts convention as function scoping is really horrible anyway.
var ops = 55;
ops++;
ops--;

// New function definitions typescript style.
// Note that despite this example having a lack of explicit type annotations, this is a *strictly* typed language.
// The types are inferred by the compiler.
function bar(foo: int, bar: int) {
	return foo + bar;
};

// This is not a part of typescript, and custom to Expressive.
// These are expression blocks, which allow you to block your code into scopes for organization.
// You can get the return value out of the last expression in the scope through implicit returns.
{
	var global = 55;
	let str = "🤖";

	{
		// Boolean values!
		let anotherone = true;
		{
			// Typed builtin array types. No more array()[1, number]
			// Every value inside of it must be the same type.
			let an_array = ["Hi"];
		}
		// 'str' also exists in here

		// 'anotherone' is dropped.
	}
	// 'global' exists in here
	print(global)
}
// 'global' exists cause it uses 'var', which defines a global variable
print(global);
// print(str); -- Errors, 'str' is only defined inside of the above scope.
```

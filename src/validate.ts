import * as vt from 'vscode-textmate/release/main';
import * as fs from 'fs';
import * as path from 'path';
import './tmlang';

enum GrammarKind {
    nix = 'source.nix',
    nixpkg = 'source.nixpkg'
}
const grammarFileNames: Record<GrammarKind, string> = {
    [GrammarKind.nix]: "Nix.tmLanguage",
    [GrammarKind.nixpkg]: "NixPackages.tmLanguage"
};
function grammarPath(kind: GrammarKind) {
    return path.join(__dirname, '..', grammarFileNames[kind]);
}
const grammarPaths = {
    [GrammarKind.nix]: grammarPath(GrammarKind.nix)
};

    // @ts-ignore
const registery = new vt.Registry({

    loadGrammar: function (scopeName: GrammarKind) {
        const path = grammarPaths[scopeName];
        if (path) {
            return new Promise((resolve, reject) => {
                fs.readFile(path, (error, content) => {
                    if (error) {
                        reject(error);
                    } else {
                        const rawGrammar = vt.parseRawGrammar(content.toString(), path);
                        resolve(rawGrammar);
                    }
                });
            });
        }

        return Promise.resolve(null);
    }
});

interface ThenableGrammar {
    kind: GrammarKind;
        // @ts-ignore
    grammar: vt.Thenable<vt.IGrammar>;
}
function thenableGrammar(kind: GrammarKind): ThenableGrammar {
    return { kind, grammar: registery.loadGrammar(kind) };
}
const tsGrammar = thenableGrammar(GrammarKind.nix);
const tsReactGrammar = thenableGrammar(GrammarKind.nixpkg);

function getInputFile(oriLines: string[]): string {
    return "original file\n-----------------------------------\n" +
        oriLines.join("\n") + 
        "\n-----------------------------------\n\n";
}

function getGrammarInfo(kind: GrammarKind) {
    return "Grammar: " + grammarFileNames[kind] + "\n-----------------------------------\n";
}

interface Grammar {
    kind: GrammarKind;
    grammar: vt.IGrammar;
    ruleStack?: vt.StackElement;
}
function initGrammar(kind: GrammarKind, grammar: vt.IGrammar): Grammar {
    return { kind, grammar };
}

function tokenizeLine(grammar: Grammar, line: string) {
    const lineTokens = grammar.grammar.tokenizeLine(line, grammar.ruleStack!);
    grammar.ruleStack = lineTokens.ruleStack;
    return lineTokens.tokens;
}

function hasDiff<T>(first: T[], second: T[], hasDiffT: (first: T, second: T) => boolean): boolean {
    if (first.length != second.length) {
        return true;
    }

    for (let i = 0; i < first.length; i++) {
        if (hasDiffT(first[i], second[i])) {
            return true;
        }
    }

    return false;
}

function makeTsScope(scope: string) {
    return scope.replace(/\.nixpkg/g, '.nix');
}

function hasDiffScope(first: string, second: string) {
    return makeTsScope(first) !== makeTsScope(second);
}

function hasDiffLineToken(first: vt.IToken, second: vt.IToken) {
    return first.startIndex != second.startIndex ||
        first.endIndex != second.endIndex ||
        hasDiff(first.scopes, second.scopes, hasDiffScope);
}

function getBaseline(grammar: Grammar, outputLines: string[]) {
    return getGrammarInfo(grammar.kind) + outputLines.join('\n');
}

export function generateScopes(text: string, parsedFileName: path.ParsedPath) {
    const mainGrammar = parsedFileName.ext === '.nixpkg' ? tsReactGrammar : tsGrammar;
    const oriLines = text.split(/\r\n|\r|\n/);
    const otherGrammar = oriLines[0].search(/\/\/\s*@onlyOwnGrammar/i) < 0 ?
        mainGrammar === tsGrammar ? tsReactGrammar : tsGrammar :
        undefined;

    return Promise.all([
        mainGrammar.grammar,
        otherGrammar ?
            otherGrammar.grammar :
            Promise.resolve(undefined)
    ]).then(([mainIGrammar, otherIGrammar]) => generateScopesWorker(
        initGrammar(mainGrammar.kind, mainIGrammar!),
        otherIGrammar && initGrammar(otherGrammar!.kind, otherIGrammar),
        oriLines
    ));
}

function validateTokenScopeExtension(grammar: Grammar, token: vt.IToken) {
    return !token.scopes.some(scope => !isValidScopeExtension(grammar, scope));
}

function isValidScopeExtension(grammar: Grammar, scope: string) {
    return scope.endsWith(grammar.kind === GrammarKind.nix ? ".nix" : ".nixpkg") ||
        scope.endsWith(".sh") ||
        scope.endsWith(".nixpkg");
}

function generateScopesWorker(mainGrammar: Grammar, otherGrammar: Grammar | undefined, oriLines: string[]): string {
    let cleanLines: string[] = [];
    let baselineLines: string[] = [];
    let otherBaselines: string[] = [];
    let markers = 0;
    let foundDiff = false;
    for (const i in oriLines) {
        let line = oriLines[i];

        const mainLineTokens = tokenizeLine(mainGrammar, line);

        cleanLines.push(line);
        baselineLines.push(">" + line);
        otherBaselines.push(">" + line);

        for (let token of mainLineTokens) {
            writeTokenLine(mainGrammar, token, baselineLines);
        }

        if (otherGrammar) {
            const otherLineTokens = tokenizeLine(otherGrammar, line);
            if (otherLineTokens.some(token => !validateTokenScopeExtension(otherGrammar, token)) ||
                hasDiff(mainLineTokens, otherLineTokens, hasDiffLineToken)) {
                foundDiff = true;
                for (let token of otherLineTokens) {
                    writeTokenLine(otherGrammar, token, otherBaselines);
                }
            }
        }
    }

    const otherDiffBaseline = foundDiff ? "\n\n\n" + getBaseline(otherGrammar!, otherBaselines) : "";
    return getInputFile(cleanLines) + getBaseline(mainGrammar, baselineLines) + otherDiffBaseline;
}

function writeTokenLine(grammar: Grammar, token: vt.IToken, outputLines: string[]) {
    let startingSpaces = " ";
    for (let j = 0; j < token.startIndex; j++) {
        startingSpaces += " ";
    }

    let locatingString = "";
    for (let j = token.startIndex; j < token.endIndex; j++) {
        locatingString += "^";
    }
    outputLines.push(startingSpaces + locatingString);
    outputLines.push(`${startingSpaces}${token.scopes.join(' ')}${validateTokenScopeExtension(grammar, token) ? "" : " INCORRECT_SCOPE_EXTENSION"}`);
}
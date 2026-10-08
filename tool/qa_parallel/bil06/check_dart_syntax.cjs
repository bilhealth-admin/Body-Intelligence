// Optional independent syntax preflight. This is not Dart analyze, Dart format,
// a Flutter test, a screenshot, or an end-to-end verification.
// Install pinned tooling in a separate scratch directory with --ignore-scripts:
// npm install --prefix TOOL_ROOT --save-exact --ignore-scripts --no-audit --no-fund \
//   web-tree-sitter@0.25.10 tree-sitter-wasms@0.1.13
// Then: node tool/qa_parallel/bil06/check_dart_syntax.cjs TOOL_ROOT REPO_ROOT

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

async function main() {
  if (!process.argv[2]) throw new Error('Usage: check_dart_syntax.cjs TOOL_ROOT [REPO_ROOT]');
  const toolRoot = path.resolve(process.argv[2]);
  const repo = path.resolve(process.argv[3] || process.cwd());
  const moduleRoot = path.join(toolRoot, 'node_modules');
  for (const [name, version] of [['web-tree-sitter', '0.25.10'], ['tree-sitter-wasms', '0.1.13']]) {
    const manifest = JSON.parse(fs.readFileSync(path.join(moduleRoot, name, 'package.json'), 'utf8'));
    if (manifest.version !== version) throw new Error('Unexpected syntax tooling version: ' + name);
  }
  const {Parser, Language} = require(path.join(moduleRoot, 'web-tree-sitter/tree-sitter.cjs'));
  await Parser.init();
  const wasm = path.join(moduleRoot, 'tree-sitter-wasms/out/tree-sitter-dart.wasm');
  const language = await Language.load(wasm);
  const parser = new Parser();
  parser.setLanguage(language);
  const files = [
    'lib/features/community/presentation/community_circles_page.dart',
    'lib/features/community/presentation/community_circle_detail_page.dart',
    'lib/features/community/presentation/community_circle_discovery_header.dart',
    'lib/features/community/presentation/community_circle_reference_body.dart',
    'lib/features/community/presentation/community_circle_owner_scope.dart',
    'lib/features/community/presentation/community_circle_copy.dart',
  ];
  function collect(directory) {
    if (!fs.existsSync(directory)) return;
    for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) collect(file);
      else if (entry.isFile() && file.endsWith('.dart')) files.push(path.relative(repo, file));
    }
  }
  collect(path.join(repo, 'lib/features/community/circle_management'));
  collect(path.join(repo, 'test/parallel/bil06'));
  const results = [];
  for (const file of [...new Set(files)].sort()) {
    const source = fs.readFileSync(path.join(repo, file), 'utf8');
    const tree = parser.parse(source);
    const errors = [];
    function visit(node) {
      if (node.type === 'ERROR' || node.isMissing) {
        errors.push({type: node.type, start: node.startPosition, end: node.endPosition});
      }
      for (const child of node.children) visit(child);
    }
    visit(tree.rootNode);
    results.push({file, sha256: crypto.createHash('sha256').update(source).digest('hex'), errors});
    tree.delete();
  }
  parser.delete();
  const errorCount = results.reduce((total, result) => total + result.errors.length, 0);
  console.log(JSON.stringify({
    checker: 'Tree-sitter Dart syntax only', compiler_validation: false,
    tooling: {'web-tree-sitter': '0.25.10', 'tree-sitter-wasms': '0.1.13'},
    grammar_sha256: crypto.createHash('sha256').update(fs.readFileSync(wasm)).digest('hex'),
    file_count: results.length, error_count: errorCount, results,
  }, null, 2));
  if (errorCount !== 0) process.exitCode = 1;
}

main().catch(error => {
  console.error(error);
  process.exitCode = 2;
});

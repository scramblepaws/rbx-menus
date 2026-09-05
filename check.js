const parser = require('luau-parser');
const fs = require('fs');
const path = process.argv[2];
if (!path) { console.error('usage: node check.js <file>'); process.exit(2); }
const src = fs.readFileSync(path, 'utf8');
try {
  const ast = parser.parse(src, { comments: true });
  const type = (ast && ast.type) ? ast.type : 'unknown';
  const count = (ast && ast.body && Array.isArray(ast.body)) ? ast.body.length : (ast && ast.statements ? ast.statements.length : '?');
  console.log(`OK: parsed ${path} (root.type=${type}, ${count} top-level nodes)`);
} catch (e) {
  console.error('PARSE ERROR in', path);
  const lines = src.split('\n');
  const ln = e.lineNumber || e.line || 0;
  console.error(`  message: ${e.message}`);
  console.error(`  line: ${ln}`);
  if (ln) {
    for (let i = Math.max(1, ln - 2); i <= Math.min(lines.length, ln + 2); i++) {
      console.error(`${String(i).padStart(4)}: ${lines[i - 1]}`);
    }
  }
  process.exit(1);
}

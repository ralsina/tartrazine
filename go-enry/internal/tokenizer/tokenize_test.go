package tokenizer

import (
	"fmt"
	"testing"

	"github.com/go-enry/go-enry/v2/regex"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	testContent = `#!/usr/bin/ruby

#!/usr/bin/env node

aaa

#!/usr/bin/env A=B foo=bar awk -f

#!python

func Tokenize(content []byte) []string {
	splitted := bytes.Fields(content)
	tokens := /* make([]string, 0, len(splitted))
	no comment -- comment
	for _, tokenByte := range splitted {
		token64 := base64.StdEncoding.EncodeToString(tokenByte)
		tokens = append(tokens, token64)
		notcatchasanumber3.5
	}*/
othercode
	/* testing multiple 
	
		multiline comments*/

<!-- com
	ment -->
<!-- comment 2-->
ppp no comment # comment

"literal1"

abb (tokenByte, 0xAF02) | ,3.2L

'literal2' notcatchasanumber3.5

	5 += number * anotherNumber
	if isTrue && isToo {
		0b00001000 >> 1
	}

	return tokens

oneBool = 3 <= 2
varBool = 3<=2>
 
#ifndef
#i'm not a comment if the single line comment symbol is not followed by a white

  PyErr_SetString(PyExc_RuntimeError, "Relative import is not supported for Python <=2.4.");

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <title id="hola" class="">This is a XHTML sample file</title>
        <style type="text/css"><![CDATA[
            #example {
                background-color: yellow;
            }
        ]]></style>
    </head>
    <body>
        <div id="example">
            Just a simple <strong>XHTML</strong> test page.
        </div>
    </body>
</html>`
)

var (
	tokensFromTestContent = []string{"SHEBANG#!ruby", "SHEBANG#!node", "SHEBANG#!awk", "<!DOCTYPE>", "html", "PUBLIC",
		"W3C", "DTD", "XHTML", "1", "0", "Strict", "EN", "http", "www", "w3", "org", "TR", "xhtml1", "DTD", "xhtml1",
		"strict", "dtd", "<html>", "xmlns=", "<head>", "<title>", "id=", "class=", "</title>", "<style>", "type=",
		"<![CDATA[>", "example", "background", "color", "yellow", "</style>", "</head>", "<body>", "<div>", "id=",
		"<strong>", "</strong>", "</div>", "</body>", "</html>", "(", "[", "]", ")", "[", "]", "{", "(", ")", "(", ")",
		"{", "}", "(", ")", ";", "#", "/usr/bin/ruby", "#", "/usr/bin/env", "node", "aaa", "#", "/usr/bin/env", "A",
		"B", "foo", "bar", "awk", "f", "#", "python", "func", "Tokenize", "content", "byte", "string", "splitted",
		"bytes.Fields", "content", "tokens", "othercode", "ppp", "no", "comment", "abb", "tokenByte",
		"notcatchasanumber", "number", "*", "anotherNumber", "if", "isTrue", "isToo", "b", "return", "tokens",
		"oneBool", "varBool", "#ifndef", "#i", "m", "not", "a", "comment", "if", "the", "single", "line", "comment",
		"symbol", "is", "not", "followed", "by", "a", "white", "PyErr_SetString", "PyExc_RuntimeError", "This", "is",
		"a", "XHTML", "sample", "file", "Just", "a", "simple", "XHTML", "test", "page.", "-", "|", "+", "&&", "<", "<",
		"!", "!", "!", "=", "=", "!", ":", "=", ":", "=", ",", ",", "=", ">", ">", "=", "=", "=", "=", ">", "'", ","}

	tests = []struct {
		name     string
		content  []byte
		expected []string
	}{
		{name: "content", content: []byte(testContent), expected: tokensFromTestContent},
	}
)

func TestTokenize(t *testing.T) {
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			before := string(test.content)
			tokens := Tokenize(test.content)
			after := string(test.content)
			require.Equal(t, before, after, "the input slice was modified")
			require.Equal(t, len(test.expected), len(tokens), fmt.Sprintf("token' slice length = %v, want %v", len(test.expected), len(tokens)))

			for i, expectedToken := range test.expected {
				assert.Equal(t, expectedToken, tokens[i], fmt.Sprintf("token = %v, want %v", tokens[i], expectedToken))
			}
		})
	}
}

func TestTokenizerLatin1AsUtf8(t *testing.T) {
	content := []byte("th\xe5 filling") // `th� filling`
	t.Logf("%v - %q", content, string(content))
	tokens := Tokenize(content)
	for i, token := range tokens {
		t.Logf("token %d, %s", i+1, token)
	}
	require.Equal(t, 3, len(tokens))
}

func TestRegexpOnInvalidUtf8(t *testing.T) {
	origContent := []struct {
		text   string
		tokens []string
	}{
		{"th\xe0 filling", []string{"th", "filling"}},   // `th� filling`
		{"th\u0100 filling", []string{"th", "filling"}}, // `thĀ filling`
		{"привет, как дела?", []string{}},               // empty, no ASCII tokens
	}
	re := regex.MustCompile(`[0-9A-Za-z_\.@#\/\*]+`) // a reRegularToken from tokenizer.go

	for _, content := range origContent {
		t.Run("", func(t *testing.T) {
			t.Logf("%v - %q", content, content.text)
			input := []byte(content.text)
			tokens := re.FindAll(input, -1)
			require.Equal(t, len(content.tokens), len(tokens))

			newContent := re.ReplaceAll(input, []byte(` `))
			t.Logf("content:%q, tokens:[", newContent)
			for i, token := range tokens {
				t.Logf("\t%q,", string(token))
				require.Equal(t, content.tokens[i], string(token))
			}
			t.Logf(" ]\n")
		})
	}
}

func BenchmarkTokenizer_BaselineCopy(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		for _, test := range tests {
			if len(test.content) > ByteLimit {
				test.content = test.content[:ByteLimit]
			}
			_ = append([]byte(nil), test.content...)
		}
	}
}

func BenchmarkTokenizer(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		for _, test := range tests {
			Tokenize(test.content)
		}
	}
}

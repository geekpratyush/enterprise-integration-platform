
async function loadMonaco() {
    if (window.monaco) return window.monaco;

    return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs/loader.min.js';
        script.onload = () => {
            window.require.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs' } });
            window.require(['vs/editor/editor.main'], () => {
                const monaco = window.monaco;
                
                // Register SWIFT MT Language
                monaco.languages.register({ id: 'swift-mt' });
                monaco.languages.setMonarchTokensProvider('swift-mt', {
                    tokenizer: {
                        root: [
                            [/^:[0-9]{2}[A-Z]{0,1}:/, 'keyword'], // Tags like :20:, :25A:
                            [/^-[A-Z]+-/, 'type'],                 // Block separators
                            [/[A-Z0-9]{8,11}/, 'string'],          // BICs
                            [/{[0-9]:/, 'tag'],                     // Block start {1:
                            [/}/, 'tag'],
                            [/[0-9]+,[0-9]*/, 'number'],           // Amounts
                        ]
                    }
                });

                monaco.editor.defineTheme('eip-theme', {
                    base: 'vs-dark',
                    inherit: true,
                    rules: [
                        { token: 'keyword', foreground: '38bdf8', fontStyle: 'bold' },
                        { token: 'tag', foreground: 'fbbf24' },
                        { token: 'string', foreground: '34d399' },
                    ],
                    colors: {
                        'editor.background': '#1e293b',
                    }
                });

                resolve(monaco);
            }, reject);
        };
        script.onerror = reject;
        document.head.appendChild(script);
    });
}

function hookSwaggerUI() {
    console.log(">>> EIP Platform: Hooking into Swagger UI for Monaco integration...");
    
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            mutation.addedNodes.forEach((node) => {
                if (node.nodeType === 1) { // Element
                    // Find textareas in "Try it out"
                    const textareas = node.querySelectorAll('textarea.body-param__text');
                    textareas.forEach(attachMonaco);
                }
            });
        });
    });

    observer.observe(document.body, { childList: true, subtree: true });
}

async function attachMonaco(textarea) {
    if (textarea.dataset.monacoAttached) return;
    textarea.dataset.monacoAttached = 'true';

    const monaco = await loadMonaco();
    const container = document.createElement('div');
    container.style.height = '300px';
    container.style.width = '100%';
    container.style.border = '1px solid #334155';
    container.style.borderRadius = '4px';
    container.style.marginTop = '10px';
    
    textarea.style.display = 'none';
    textarea.parentNode.insertBefore(container, textarea);

    // Determine language based on content or endpoint
    let lang = 'json';
    const content = textarea.value;
    if (content.startsWith('<')) lang = 'xml';
    else if (content.startsWith(':')) lang = 'swift-mt';

    const editor = monaco.editor.create(container, {
        value: textarea.value,
        language: lang,
        theme: 'eip-theme',
        automaticLayout: true,
        minimap: { enabled: false },
        fontSize: 13,
        fontFamily: "'JetBrains Mono', monospace",
    });

    editor.onDidChangeModelContent(() => {
        textarea.value = editor.getValue();
        // Trigger Swagger UI internal change event
        const event = new Event('input', { bubbles: true });
        textarea.dispatchEvent(event);
    });
}

// Start hooking when DOM is semi-ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', hookSwaggerUI);
} else {
    hookSwaggerUI();
}

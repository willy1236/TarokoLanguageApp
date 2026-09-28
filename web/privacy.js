// 把 privacy.html 內的 Markdown 原文轉成 HTML。獨立成檔是為了讓 CSP 不必放行 inline script。
document.getElementById('content').innerHTML = marked.parse(document.getElementById('src').textContent);

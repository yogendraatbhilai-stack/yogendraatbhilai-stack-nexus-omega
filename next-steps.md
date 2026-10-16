# Adding "Save to Nexus" to the remaining tools

All four tools are now wired to Nexus:

| Tool                       | toolKey                     | sectionKey             | Status |
|------------------------------|-------------------------------|---------------------------|--------|
| Retirement Planner            | `retirement_planner`          | `sales`                    | ✅ Done |
| CBA Tool                       | `cba_tool`                     | `sales`                    | ✅ Done |
| Table Performance Manager     | `table_performance_manager`   | `sales`                    | ✅ Done |
| Event SOP Governance          | `event_sop`                    | `customer_awareness`       | ✅ Done |

If you build a **new** tool and want to add it to Nexus later, follow this
same 4-step pattern (copy from any tool above and adjust field names):

1. **Find the tool's existing report/output** — the piece of HTML or PDF
   it already produces when someone finishes using it.
2. **Get a PDF Blob of it.**
   - If the tool already has its own fully-branded print layout (like
     Retirement Planner's `.report` div or the CBA Tool's `#report-content`),
     use `NexusBridge.captureElementAsPdf(element, filename)` — captures it
     exactly as designed, no extra letterhead.
   - If the tool only has a plain HTML snippet (like Table Performance
     Manager's daily report), use `NexusBridge.exportBrandedPDF({ title,
     subtitle, bodyHtml, filename, download:false })` — wraps it in the
     Omega letterhead automatically.
   - If the tool uses jsPDF directly (like Event SOP), just call
     `pdf.output('blob')`.
3. **Add one button** next to the tool's existing "Download" button, and
   make sure `html2pdf.js` is loaded via CDN in that page (needed by
   `captureElementAsPdf` / `exportBrandedPDF`, not needed for jsPDF tools):
   ```html
   <script src="https://cdn.jsdelivr.net/npm/html2pdf.js@0.10.1/dist/html2pdf.bundle.min.js"></script>
   ```
4. **Write the click handler**, following this shape:
   ```js
   async function saveToNexus(){
     const blob = /* pdf blob from step 2 */;
     await NexusBridge.saveReport({
       toolKey: 'your_tool_key',        // must match a row in supabase/schema.sql -> tools
       sectionKey: 'sales',              // or 'customer_awareness'
       clientName: /* client, candidate, or event name */,
       summary: /* one-line summary shown in Reports libraries */,
       data: { /* whatever fields are useful to keep queryable later */ },
       pdfBlob: blob
     });
     nexusToast('Saved to Nexus.', 'ok');
   }
   ```

## ⚠️ One thing to watch for on any new tool

Before wiring a tool, **check whether any of its own JavaScript contains
the literal text `</body>` inside a string** (for example, a feature that
builds a downloadable HTML report). If it does, don't do a simple
"replace the first `</body>`" edit — that text match might be inside a
string, not the page's real closing tag, and can corrupt the tool. Always
insert Nexus's login-check scripts right before the **last** `</body>` in
the file, and never place a raw `<script>...</script>` tag inside another
tool's JS template literal — escape it as `<\/script>` if you ever need to
reference it inside a string, exactly like the working "Print" feature in
Table Performance Manager already does.

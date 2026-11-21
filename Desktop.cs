using System;
using System.Data;
using System.Drawing;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace LandOffice
{
    public sealed class Desktop : Form
    {
        private readonly Counter counter;
        private readonly TextBox title = new TextBox { Name = "TitleEntry", MaxLength = 200, Dock = DockStyle.Fill };
        private readonly Button add = new Button { Name = "AddTask", Text = "&File task", AutoSize = true };
        private readonly Button done = new Button { Name = "Discharge", Text = "&Mark done", AutoSize = true };
        private readonly Button inspect = new Button { Name = "Inspect", Text = "&Read deed", AutoSize = true };
        private readonly Button refresh = new Button { Name = "Refresh", Text = "Re&fresh", AutoSize = true };
        private readonly TextBox receipt = new TextBox { Name = "ReceiptText", Multiline = true, ReadOnly = true, Dock = DockStyle.Fill, ScrollBars = ScrollBars.Vertical };
        private readonly DataGridView grid = new DataGridView {
            Name = "TodoLedger", Dock = DockStyle.Fill, ReadOnly = true, AllowUserToAddRows = false,
            AllowUserToDeleteRows = false, MultiSelect = false, SelectionMode = DataGridViewSelectionMode.FullRowSelect,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill
        };
        private Guid petition = Guid.NewGuid();

        public Desktop(Counter counter)
        {
            this.counter = counter;
            Text = "Checkbox Land Office";
            MinimumSize = new Size(600, 420);
            Size = new Size(760, 510);
            var page = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(12), ColumnCount = 1, RowCount = 5 };
            page.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            page.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            page.RowStyles.Add(new RowStyle(SizeType.Absolute, 80));
            var filing = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, AutoSize = true };
            filing.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            filing.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            filing.Controls.Add(title, 0, 0);
            filing.Controls.Add(add, 1, 0);
            var actions = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill };
            actions.Controls.AddRange(new Control[] { done, inspect, refresh });
            page.Controls.Add(new Label { Text = "Task title", AutoSize = true });
            page.Controls.Add(filing);
            page.Controls.Add(grid);
            page.Controls.Add(actions);
            page.Controls.Add(receipt);
            Controls.Add(page);
            AcceptButton = add;
            title.AccessibleName = "Task title";
            add.AccessibleName = "File task";
            done.AccessibleName = "Mark done";
            receipt.AccessibleName = "Recorded deeds";
            title.TextChanged += delegate { petition = Guid.NewGuid(); };
            Shown += async delegate { await Busy(() => Reload(null)); };
            add.Click += async delegate {
                string text = title.Text;
                Guid number = petition;
                await Busy(async () => {
                    int id = await Task.Run(() => counter.Add(text, number));
                    await Reload(id);
                    title.Clear();
                });
            };
            done.Click += async delegate {
                int? id = Selected();
                if (id.HasValue) await Busy(async () => {
                    await Task.Run(() => counter.Done(id.Value));
                    await Reload(id);
                });
            };
            inspect.Click += async delegate {
                int? id = Selected();
                if (id.HasValue) await Busy(() => ShowReceipt(id.Value));
            };
            refresh.Click += async delegate { await Busy(() => Reload(Selected())); };
        }

        private int? Selected()
        {
            return grid.CurrentRow == null ? (int?)null : (int)grid.CurrentRow.Cells["TaskId"].Value;
        }

        private async Task Reload(int? select)
        {
            grid.DataSource = await Task.Run(() => counter.List());
            if (select.HasValue)
                foreach (DataGridViewRow row in grid.Rows)
                    if ((int)row.Cells["TaskId"].Value == select.Value) grid.CurrentCell = row.Cells["Title"];
            int? id = Selected();
            if (id.HasValue) await ShowReceipt(id.Value);
            else receipt.Clear();
        }

        private async Task ShowReceipt(int id)
        {
            DataTable deeds = await Task.Run(() => counter.Receipt(id));
            var text = new StringBuilder();
            foreach (DataRow deed in deeds.Rows)
                text.AppendFormat("#{0} {1} • mint {2} • {3} hearings • {4} policies • {5} cents payable to {6}.{7}",
                    id, deed["Act"], deed["Stamp"], deed["Hearings"], deed["Contracts"], deed["SettledCents"], deed["Payee"], Environment.NewLine);
            receipt.Text = text.ToString();
        }

        private async Task Busy(Func<Task> action)
        {
            if (!Enabled) return;
            Enabled = false;
            try { await action(); }
            catch (Exception ex) { receipt.Text = ex.Message; }
            finally { Enabled = true; }
        }

        [STAThread]
        public static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try {
                string connection = Environment.GetEnvironmentVariable("MULLET_SQL");
                if (String.IsNullOrWhiteSpace(connection))
                    connection = File.ReadAllText(Path.Combine(Counter.Countertop, "land-office.connection")).Trim();
                Application.Run(new Desktop(new Counter(connection)));
            } catch (Exception ex) {
                MessageBox.Show(ex.Message, "Checkbox Land Office");
            }
        }
    }
}

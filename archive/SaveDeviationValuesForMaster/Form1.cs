namespace SaveDeviationValuesForMaster
{
    public partial class Form1 : Form
    {

        public Form1()
        {
            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            var ID = textBox37.Text;

            TextBox[] textBoxes = {
            textBox1, textBox2, textBox3, textBox4, textBox5,
            textBox6, textBox7, textBox8, textBox9, textBox10,
            textBox11, textBox12, textBox13, textBox14, textBox15,
            textBox16, textBox17, textBox18, textBox19, textBox20,
            textBox21, textBox22, textBox23, textBox24, textBox25,
            textBox26, textBox27, textBox28, textBox29, textBox30,
            textBox31, textBox32, textBox33, textBox34, textBox35,
            textBox36};

            List<double> numbers = new List<double>();
            for (int i = 0; i < textBoxes.Length; i++)
            {
                if (double.TryParse(textBoxes[i].Text, out double result))
                {
                    numbers[i] = result;
                }
                else
                {
                    numbers[i] = double.NaN;
                }
            }
        }
    }
}

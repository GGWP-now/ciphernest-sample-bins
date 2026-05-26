#include <iostream>
#include <string>
#include <sstream>
#include <cstdlib>

// Protected-style calculation function — candidate for #[protect] annotation.
// Returns the result of (a op b) on success, or exits with an error message on
// invalid operator or division by zero.
static int do_calc(int a, char op, int b)
{
    switch (op)
    {
    case '+':
        return a + b;
    case '-':
        return a - b;
    case '*':
        return a * b;
    case '/':
        if (b == 0)
        {
            std::cerr << "error: division by zero\n";
            std::exit(1);
        }
        return a / b;
    default:
        std::cerr << "error: unknown operator '" << op << "'\n";
        std::exit(1);
    }
}

int main()
{
    std::string line;

    while (true)
    {
        std::cout << "Enter operation (e.g. 5 + 3) or 'q' to quit:\n";

        if (!std::getline(std::cin, line))
            break; // EOF or read error

        if (line == "q" || line == "Q")
            break;

        std::istringstream iss(line);
        int a = 0, b = 0;
        char op = 0;

        if (!(iss >> a >> op >> b))
        {
            std::cerr << "error: invalid input — expected: <number> <op> <number>\n";
            continue;
        }

        int result = do_calc(a, op, b);
        std::cout << a << " " << op << " " << b << " = " << result << "\n";
    }

    return 0;
}

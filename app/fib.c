
int fib(int n) {
    if (n <= 1) {
        return 1;
    }

    return fib(n - 1) + fib(n - 2);
}

int main() {
    int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += fib(i);
    }
    return sum;
}
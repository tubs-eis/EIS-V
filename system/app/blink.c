void wait(int duration) {
    for (volatile int i = 0; i < duration; i++) {
    }
}

int main() {
    int* volatile leds = (int*)0x80000000;
    int led_pos = 0;
    int direction = 0;
    //*leds = 0x5A;
    while (1) {
        *leds = (1 << led_pos);
        if (direction == 0) {
            led_pos++;
            if (led_pos == 3) {
                direction = 1;
            }
        } else {
            led_pos--;
            if (led_pos == 0) {
                direction = 0;
            }
        }
        wait(160000);
    }
}
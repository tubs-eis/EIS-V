#include "memory.h"

#include <cstdio>
#include <random>

Memory::Memory(size_t size) : memory(size, 0) {}

bool Memory::init_from_file(char const* path, int offset) {
    std::ifstream ifile(path, std::ios::binary);
    if (!ifile.is_open()) {
        return false;
    }

    while (!ifile.eof() && offset < memory.size()) {
        uint32_t value;
        ifile.read(reinterpret_cast<char*>(&value), sizeof(value));
        memory[offset] = value;
        offset++;
    }

    ifile.close();
    return true;
}

void Memory::init_random() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<uint32_t> dis;

    for (int i = 0; i < memory.size(); i++) {
        memory[i] = dis(gen);
    }
}

bool Memory::write_to_file(char const* path) {
    std::FILE* out_file = std::fopen(path, "w");
    if (!out_file) {
        return false;
    }

    fwrite(memory.data(), sizeof(uint32_t), memory.size(), out_file);

    std::fflush(out_file);
    std::fclose(out_file);

    return true;
}

bool Memory::write(uint32_t local_address, uint32_t value, uint8_t byte_enable) {
    size_t word_addr = local_address >> 2;

    if (word_addr >= memory.size()) {
        return false;
    }

    uint32_t new_value = memory[word_addr];
    for (int i = 0; i < 4; i++) {
        uint32_t mask = (0xff << (8 * i));

        if (byte_enable & (1 << i)) {
            new_value &= ~mask;
            new_value |= value & mask;
        }
    }

    memory[word_addr] = new_value;

    return true;
}

bool Memory::read(uint32_t local_address, uint32_t& value_out, uint8_t byte_enable) {
    size_t word_addr = local_address >> 2;

    if (word_addr >= memory.size()) {
        return false;
    }

    uint32_t word_read = memory[word_addr];

    uint32_t value = 0;
    for (int i = 0; i < 4; i++) {
        value |= word_read & (0xff << (8 * i));
    }
    // printf("Read %08x from IMEM at %08x\n", word_read, word_addr);

    value_out = value;

    return true;
}
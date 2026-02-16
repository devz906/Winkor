#ifndef IOS_ELF_H
#define IOS_ELF_H

// iOS ELF compatibility header
// iOS doesn't have elf.h, so we recreate the necessary parts

#include <stdint.h>
#include <sys/types.h>

// ELF file types
#define ET_NONE         0      // No file type
#define ET_REL          1      // Relocatable file
#define ET_EXEC         2      // Executable file
#define ET_DYN          3      // Shared object file
#define ET_CORE         4      // Core file

// ELF machine types
#define EM_NONE         0      // No machine
#define EM_386          3      // Intel 80386
#define EM_X86_64       62     // AMD x86-64 architecture
#define EM_AARCH64      183    // ARM AARCH64

// ELF class and data
#define ELFCLASS32      1      // 32-bit objects
#define ELFCLASS64      2      // 64-bit objects
#define ELFDATA2LSB     1      // 2's complement, little endian
#define ELFDATA2MSB     2      // 2's complement, big endian

// ELF version
#define EV_NONE         0      // Invalid version
#define EV_CURRENT      1      // Current version

// Section header types
#define SHT_NULL        0      // Section header table entry unused
#define SHT_PROGBITS    1      // Program data
#define SHT_SYMTAB      2      // Symbol table
#define SHT_STRTAB      3      // String table
#define SHT_RELA        4      // Relocation entries with addends
#define SHT_HASH        5      // Symbol hash table
#define SHT_DYNAMIC     6      // Dynamic linking information
#define SHT_NOTE        7      // Notes
#define SHT_NOBITS      8      // Program space with no data (bss)
#define SHT_REL         9      // Relocation entries, no addends
#define SHT_SHLIB       10     // Reserved
#define SHT_DYNSYM      11     // Dynamic linker symbol table

// Section header flags
#define SHF_WRITE       0x1     // Writable
#define SHF_ALLOC       0x2     // Occupies memory during execution
#define SHF_EXECINSTR   0x4     // Executable
#define SHF_MASKPROC     0xf0000000 // Processor-specific

// Symbol binding
#define STB_LOCAL       0      // Local symbol
#define STB_GLOBAL      1      // Global symbol
#define STB_WEAK        2      // Weak symbol
#define STB_NUM         3      // Number of defined types

// Symbol type
#define STT_NOTYPE      0      // Symbol type is unspecified
#define STT_OBJECT      1      // Symbol is a data object
#define STT_FUNC        2      // Symbol is a code object
#define STT_SECTION     3      // Symbol associated with a section
#define STT_FILE        4      // Symbol's name is file name
#define STT_COMMON      5      // Symbol is a common data object
#define STT_TLS         6      // Symbol is thread-local data object
#define STT_NUM         7      // Number of defined types

// Relocation types
#define R_X86_64_NONE   0      // No reloc
#define R_X86_64_64     1      // Direct 64 bit
#define R_X86_64_PC32   2      // PC relative 32 bit signed
#define R_X86_64_GOT32  3      // 32 bit GOT entry
#define R_X86_64_PLT32  4      // 32 bit PLT address
#define R_X86_64_COPY   5      // Copy symbol at runtime
#define R_X86_64_GLOB_DAT 6    // Create GOT entry
#define R_X86_64_JUMP_SLOT 7   // Create PLT entry
#define R_X86_64_RELATIVE 8    // Adjust by program base
#define R_X86_64_32     9      // Direct 32 bit
#define R_X86_64_32S    10     // Direct 32 bit sign extended
#define R_X86_64_16     11     // Direct 16 bit
#define R_X86_64_PC16   12     // 16 bit sign extended pc relative
#define R_X86_64_8      13     // Direct 8 bit
#define R_X86_64_PC8    14     // 8 bit sign extended pc relative

// ELF header structures
typedef struct {
    unsigned char e_ident[16]; // Magic number and other info
    uint16_t      e_type;      // Object file type
    uint16_t      e_machine;   // Architecture
    uint32_t      e_version;   // Object file version
    uint64_t      e_entry;     // Entry point virtual address
    uint64_t      e_phoff;     // Program header table file offset
    uint64_t      e_shoff;     // Section header table file offset
    uint32_t      e_flags;     // Processor-specific flags
    uint16_t      e_ehsize;    // ELF header size in bytes
    uint16_t      e_phentsize; // Program header table entry size
    uint16_t      e_phnum;     // Program header table entry count
    uint16_t      e_shentsize; // Section header table entry size
    uint16_t      e_shnum;     // Section header table entry count
    uint16_t      e_shstrndx;  // Section header string table index
} Elf64_Ehdr;

typedef struct {
    uint32_t   sh_name;      // Section name (string tbl index)
    uint32_t   sh_type;      // Section type
    uint64_t   sh_flags;     // Section flags
    uint64_t   sh_addr;      // Section virtual addr at execution
    uint64_t   sh_offset;    // Section file offset
    uint64_t   sh_size;      // Section size in bytes
    uint32_t   sh_link;      // Link to another section
    uint32_t   sh_info;      // Additional section information
    uint64_t   sh_addralign; // Section alignment
    uint64_t   sh_entsize;   // Entry size if section holds table
} Elf64_Shdr;

typedef struct {
    uint32_t   st_name;      // Symbol name (string tbl index)
    unsigned char st_info;    // Symbol type and binding
    unsigned char st_other;   // Symbol visibility
    uint16_t   st_shndx;     // Section index
    uint64_t   st_value;     // Symbol value
    uint64_t   st_size;      // Symbol size
} Elf64_Sym;

typedef struct {
    uint64_t   r_offset;     // Offset
    uint64_t   r_info;       // Symbol index and type
    int64_t    r_addend;     // Addend
} Elf64_Rela;

// ELF magic number
#define EI_NIDENT 16
#define ELFMAG0 0x7f
#define ELFMAG1 'E'
#define ELFMAG2 'L'
#define ELFMAG3 'F'

// Helper macros
#define ELF64_R_SYM(i)  ((i) >> 32)
#define ELF64_R_TYPE(i) ((i) & 0xffffffff)
#define ELF64_R_INFO(s,t)  (((s) << 32) + ((t) & 0xffffffff))

#endif // IOS_ELF_H

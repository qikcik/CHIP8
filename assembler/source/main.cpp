#include <iostream>
#include <vector>
#include <cstdint>
#include <sstream>
#include <fstream>
#include <map>
#include <functional>
#include <queue>
#include "tokenIterator.hpp"

struct Context
{
    std::vector<uint8_t> output;
    void push(uint16_t in) {
        output.push_back( uint8_t((in >> 1*8)) );
        output.push_back( uint8_t((in >> 0*8)) );
    }

    struct addrRef {
        int targetLocation {-1};
        std::vector<int> addressToPut {};
    };

    std::map<std::string,addrRef> addrRefs {};
};

using TokenMatcher = std::function<bool(Token::type&)>;
using OutputGenerator = std::function<void(Context& context, std::vector<Token::type>, size_t startIdx)>;

auto ExactLabel = [](std::string param) -> TokenMatcher  {
    return [param](Token::type& t) -> bool {
        if (const auto* typedToken = std::get_if<Token::Label>(&t)) {
            return typedToken->value == param;
        }
        return false;
    };
};


auto AnyLabel = []() -> TokenMatcher  {
    return [](Token::type& t) -> bool {
        if (const auto* typedToken = std::get_if<Token::Label>(&t)) {
            return true;
        }
        return false;
    };
};

auto ExactOperator = [](std::string param) -> TokenMatcher  {
    return [param](Token::type& t) -> bool {
        if (const auto* typedToken = std::get_if<Token::Operator>(&t)) {
            return typedToken->value == param;
        }
        return false;
    };
};

auto AnyNumberOrLabel = []() -> TokenMatcher  {
    return [](Token::type& t) -> bool {
        if (const auto* typedToken = std::get_if<Token::Label>(&t)) {
            return true;
        }
        if (const auto* typedToken = std::get_if<Token::Number>(&t)) {
            return true;
        }
        return false;
    };
};

auto AnyNumber = []() -> TokenMatcher  {
    return [](Token::type& t) -> bool {
        if (const auto* typedToken = std::get_if<Token::Number>(&t)) {
            return true;
        }
        return false;
    };
};

auto Any = []() -> TokenMatcher  {
    return [](Token::type& t) -> bool {
        return true;
    };
};

int8_t getRegNum(const std::string& input) {
    if(input == "reg0") return 0;
    if(input == "reg1") return 1;
    if(input == "reg2") return 2;
    if(input == "reg3") return 3;
    if(input == "reg4") return 4;
    if(input == "reg5") return 5;
    if(input == "reg6") return 6;
    if(input == "reg7") return 7;
    if(input == "reg8") return 8;
    if(input == "reg9") return 9;
    if(input == "reg10") return 10;
    if(input == "reg11") return 11;
    if(input == "reg12") return 12;
    if(input == "reg13") return 13;
    if(input == "reg14") return 14;
    if(input == "reg15") return 15;
    return -1;
}

auto AnyGenericReg = []() -> TokenMatcher  {
    return [](Token::type& t) -> bool {
        if (const auto* typedToken = std::get_if<Token::Label>(&t)) {
            return getRegNum(typedToken->value) != -1;
        }
        return false;
    };
};

auto CCCCOutput = [](uint16_t param) -> OutputGenerator  {
    return [param](Context& context, const std::vector<Token::type>&, size_t startIdx)  {
        context.push(param);
    };
};

auto ByteOutput = []() -> OutputGenerator  {

    return [](Context& context, const std::vector<Token::type>& tokens, size_t startIdx) {

        int value {};

        if (const auto* typedToken = std::get_if<Token::Number>(&tokens[startIdx+1])) {
            value = typedToken->value;
        }
        else {
            exit(-1);
        }

        context.output.push_back( uint8_t((value >> 0*8)) );
    };
};

auto CNNNOutput = [](uint16_t param, int nnnIdx) -> OutputGenerator  {

    return [param,nnnIdx](Context& context, const std::vector<Token::type>& tokens, size_t startIdx) {

        int nnn {};

        if (const auto* typedToken = std::get_if<Token::Number>(&tokens[startIdx+nnnIdx])) {
            nnn = typedToken->value;
        }
        else if (const auto* typedToken = std::get_if<Token::Label>(&tokens[startIdx+nnnIdx])) {
            context.addrRefs[typedToken->value].addressToPut.push_back(context.output.size());
        }
        else {
            exit(-1);
        }

        uint16_t out = param    | (uint8_t((nnn >> 2 * 4)) & 0b1111) << 2 * 4
                        | (uint8_t((nnn >> 1 * 4))  & 0b1111) << 1 * 4
                        | (uint8_t((nnn >> 0 * 4))  & 0b1111) << 0 * 4;

        context.push(out);
    };
};

auto CXKKOutput = [](uint16_t param) -> OutputGenerator  {

    return [param](Context& context, const std::vector<Token::type>& tokens, size_t startIdx) {

        int x {};
        int kk {};

        if (const auto* typedToken = std::get_if<Token::Label>(&tokens[startIdx+1])) {
            x = getRegNum(typedToken->value);
        }
        if (const auto* typedToken = std::get_if<Token::Number>(&tokens[startIdx+2])) {
            kk = typedToken->value;
        }

        int opcode = param | (uint8_t(x) & 0b1111) << 2 * 4
                     | (uint8_t(kk >> 1 * 4)  & 0b1111) << 1 * 4
                     | (uint8_t(kk >> 0 * 4)  & 0b1111) << 0 * 4;

        context.push(opcode);
    };
};
auto CXCCOutput = [](uint16_t param, uint16_t xIdx) -> OutputGenerator  {

    return [param,xIdx](Context& context, const std::vector<Token::type>& tokens, size_t startIdx) {

        int x {};

        if (const auto* typedToken = std::get_if<Token::Label>(&tokens[startIdx+xIdx])) {
            x = getRegNum(typedToken->value);
        }

        int opcode = param | (uint8_t(x) & 0b1111) << 2 * 4;

        context.push(opcode);
    };
};

auto CXYCOutput = [](uint16_t param) -> OutputGenerator  {

    return [param](Context& context, const std::vector<Token::type>& tokens, size_t startIdx) {

        int x {};
        int y {};

        if (const auto* typedToken = std::get_if<Token::Label>(&tokens[startIdx+1])) {
            x = getRegNum(typedToken->value);
        }
        if (const auto* typedToken = std::get_if<Token::Label>(&tokens[startIdx+2])) {
            y = getRegNum(typedToken->value);
        }

        int opcode = param | (uint8_t(x) & 0b1111) << 2 * 4 | (uint8_t(y) & 0b1111) << 1 * 4;

        context.push(opcode);
    };
};

auto CXYNOutput = [](uint16_t param) -> OutputGenerator  {

    return [param](Context& context, const std::vector<Token::type>& tokens, size_t startIdx) {

        int x {};
        int y {};
        int n {};

        if (const auto* typedToken = std::get_if<Token::Label>(&tokens[startIdx+1])) {
            x = getRegNum(typedToken->value);
        }
        if (const auto* typedToken = std::get_if<Token::Label>(&tokens[startIdx+2])) {
            y = getRegNum(typedToken->value);
        }
        if (const auto* typedToken = std::get_if<Token::Number>(&tokens[startIdx+3])) {
            n = typedToken->value;
        }

        int opcode = param | (uint8_t(x) & 0b1111) << 2 * 4 | (uint8_t(y) & 0b1111) << 1 * 4 | (uint8_t(n) & 0b1111) << 0 * 4;

        context.push(opcode);
    };
};

auto RegisterAddress = []() -> OutputGenerator  {
    return [](Context& context, const std::vector<Token::type>& tokens, size_t startIdx) {
        if (const auto* typedToken = std::get_if<Token::Label>(&tokens[startIdx+1])) {
            if( context.addrRefs[typedToken->value].targetLocation != -1 )
            {
                std::cout << "redefinition of label: " << typedToken->value << std::endl;
                exit(-1);
            }
            context.addrRefs[typedToken->value].targetLocation = 0x200 + context.output.size();
            return;
        }

        exit(-1);
    };
};

struct OpCode
{
    std::vector<TokenMatcher> tokenSequence;
    OutputGenerator generator;
};

std::vector<OpCode> opcodes = {
    OpCode{{ExactOperator(";"),Any()}, [](auto a, auto b, auto c){} },
    OpCode{ {ExactOperator(":"), AnyLabel()}, RegisterAddress() },
    OpCode{{ExactLabel("db"),AnyNumber()}, ByteOutput() },

    OpCode{{ExactLabel("cls")}, CCCCOutput(0x00E0) },
    OpCode{{ExactLabel("ret")}, CCCCOutput(0x00EE) },
    OpCode{{ExactLabel("sys"), AnyNumberOrLabel()}, CNNNOutput(0x0000,1) },
    OpCode{{ExactLabel("call"), AnyNumberOrLabel()}, CNNNOutput(0x2000,1) },
    OpCode{{ExactLabel("se"), AnyGenericReg(), AnyNumber()}, CXKKOutput(0x3000) },
    OpCode{{ExactLabel("sne"), AnyGenericReg(), AnyNumber()}, CXKKOutput(0x4000) },
    OpCode{{ExactLabel("se"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x5000) },
    OpCode{{ExactLabel("ld"), AnyGenericReg(), AnyNumber()}, CXKKOutput(0x6000) },
    OpCode{{ExactLabel("add"), AnyGenericReg(), AnyNumber()}, CXKKOutput(0x7000) },
    OpCode{{ExactLabel("ld"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x8000) },
    OpCode{{ExactLabel("or"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x8001) },
    OpCode{{ExactLabel("and"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x8002) },
    OpCode{{ExactLabel("xor"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x8003) },
    OpCode{{ExactLabel("add"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x8004) },
    OpCode{{ExactLabel("sub"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x8005) },
    OpCode{{ExactLabel("shr"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x8006) },
    OpCode{{ExactLabel("subn"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x8007) },
    OpCode{{ExactLabel("shl"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x800E) },
    OpCode{{ExactLabel("sne"), AnyGenericReg(), AnyGenericReg()}, CXYCOutput(0x9000) },

    OpCode{{ExactLabel("jp"), ExactLabel("reg0"),ExactOperator("+"),AnyNumberOrLabel()}, CNNNOutput(0xB000,3) },
    OpCode{{ExactLabel("jp"), AnyNumberOrLabel()}, CNNNOutput(0x1000,1) },

    OpCode{{ExactLabel("rnd"), AnyGenericReg(), AnyNumber()}, CXKKOutput(0xC000) },
    OpCode{{ExactLabel("drw"), AnyGenericReg(),AnyGenericReg(), AnyNumber()}, CXYNOutput(0xD000) },

    OpCode{{ExactLabel("skp"), AnyGenericReg()}, CXCCOutput( 0xE09E,1 ) },
    OpCode{{ExactLabel("sknp"), AnyGenericReg()}, CXCCOutput( 0xE0A1,1 ) },
    OpCode{{ExactLabel("ld"), AnyGenericReg(),ExactLabel("delayTimer")}, CXCCOutput( 0xF007,1 ) },
    OpCode{{ExactLabel("ld"), AnyGenericReg(),ExactLabel("keyPress")}, CXCCOutput( 0xF00A,1) },

    OpCode{{ExactLabel("ld"), ExactLabel("delayTimer"),AnyGenericReg()}, CXCCOutput( 0xF015,2 ) },
    OpCode{{ExactLabel("ld"), ExactLabel("soundTimer"),AnyGenericReg()}, CXCCOutput( 0xF018,2 ) },

    OpCode{{ExactLabel("add"), ExactLabel("regI"),AnyGenericReg()}, CXCCOutput( 0xF01E, 2 ) },
    OpCode{{ExactLabel("ld"), ExactLabel("regI"),ExactLabel("spriteOf"),AnyGenericReg()}, CXCCOutput( 0xF029,3) },
    OpCode{{ExactLabel("ld"), ExactLabel("regI"),AnyNumberOrLabel()}, CNNNOutput(0xA000,2) },
    OpCode{{ExactLabel("ld"), ExactOperator("*"),ExactLabel("regI"),ExactLabel("bcdOf"),AnyGenericReg()}, CXCCOutput( 0xF033,4 ) },
    OpCode{{ExactLabel("ld"), ExactOperator("*"),ExactLabel("regI"),ExactLabel("upTo"), AnyGenericReg()}, CXCCOutput( 0xF055,4 ) },
    OpCode{{ExactLabel("ld"), ExactLabel("upTo"), AnyGenericReg(), ExactOperator("*"),ExactLabel("regI")}, CXCCOutput( 0xF065,2 ) }
};



int main(int argc, char * argv[]) {
    std::ifstream file;

    if(argc > 1)
        file.open(argv[1]);
    else
        file.open("./source.c8asm");

    if(!file.good()) {
        std::cout << "couldn't open file: " << argv[1];
        return -1;
    }

    std::stringstream stream{};
    stream << file.rdbuf();
    std::string source = stream.str();
    Context context;
    TokenIterator it(source);
    it.addOperator(":");
    it.addOperator(";");
    it.addOperator("+");
    it.addOperator("*");

    std::vector<Token::type> tokens {};
    int consumedIndex = 0;

    while(!std::holds_alternative<Token::End>(it.next()))
    {
        tokens.push_back(it.current());
    }

    while(consumedIndex < tokens.size())
    {
        bool anyMatch = false;
        for(auto opcode : opcodes)
        {
            int matcherIdx = 0;
            bool success = true;
            for(auto matcher : opcode.tokenSequence)
            {
                if(!matcher(tokens[consumedIndex + matcherIdx])) {
                    success = false;
                    break;
                }

                matcherIdx++;
            }

            if(!success) {
                continue;
            }

            opcode.generator(context,tokens,consumedIndex);


            consumedIndex += opcode.tokenSequence.size();
            anyMatch = true;
            break;
        }

        if(!anyMatch) {
            std::cout << "couldn't consume next opcode, starting at:" << tokens[consumedIndex];
            exit(-2);
        }


    }

    std::cout << "linking symbols" << std::endl;

    for(auto pairIt : context.addrRefs) {
        if(pairIt.second.targetLocation == -1) {
            std::cout << "symbol " << pairIt.first << " was used, but not defined";
            return -1;
        }
        for(auto it : pairIt.second.addressToPut) {
            context.output[it] = (context.output[it] & 0b11110000) | pairIt.second.targetLocation >> 2 * 4 & 0b1111;
            context.output[it+1] = pairIt.second.targetLocation;
        }
    }

    std::cout << "saving output: ";
    std::ofstream fs("output.ch8", std::ios::out | std::ios::binary | std::ios::trunc);
    for(auto it : context.output) {
        std::cout << std::hex << (int)it << " ";
        fs << it;
    }
    fs.close();

    return 0;
}

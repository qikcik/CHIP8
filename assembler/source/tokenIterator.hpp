#pragma once

#include <string>
#include <vector>
#include <variant>



namespace Token
{
    struct Base {
        int line {};
    };

    template<typename T>
    struct WithValue : public Base
    {
        T value;
    };

    struct End      : public Base {};
    struct Operator : public WithValue<std::string> {};
    struct Label    : public WithValue<std::string> {};
    struct String   : public WithValue<std::string> {};
    struct Number   : public WithValue<int> {};

    using type = std::variant<End,Operator,Label,String,Number>;
}

std::ostream& operator<<(std::ostream& os, const Token::type& in);

class TokenIterator
{
public:
    explicit TokenIterator(const std::string& inSource);

    void addOperator(const std::string& in_value);

    const Token::type& next();
    const Token::type& current();

protected:
    bool tryTokenizeNumber();
    bool tryTokenizeString();
    bool tryTokenizeOperator();
    bool tryTokenizeLabel();
protected:
    const std::string& source;
    int currentLine {1};

    size_t positionIdx {};
    Token::type currentToken {};
    std::vector<std::string> registeredOperats {};
};

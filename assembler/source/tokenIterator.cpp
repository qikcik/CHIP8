#include "tokenIterator.hpp"
#include <algorithm>
#include <stack>
#include <ostream>

std::ostream& operator<<(std::ostream& os, const Token::type& in)
{
    if (const auto* typedToken = std::get_if<Token::End>(&in)) {
        os << "Token::End{} at line:" << typedToken->line;
    }
    else if (const auto* typedToken = std::get_if<Token::Operator>(&in)) {
        os << "Token::Operator{" << typedToken->value << "} at line:" << typedToken->line;
    }
    else if (const auto* typedToken = std::get_if<Token::Label>(&in)) {
        os << "Token::Label{" << typedToken->value << "} at line:" << typedToken->line;
    }
    else if (const auto* typedToken = std::get_if<Token::String>(&in)) {
        os << "Token::String{" << typedToken->value << "} at line:" << typedToken->line;
    }
    else if (const auto* typedToken = std::get_if<Token::Number>(&in)) {
        os << "Token::Number{" << typedToken->value << "} at line:" << typedToken->line;
    }
    return os;
}

TokenIterator::TokenIterator(const std::string& inSource) : source(inSource)
{
}

void TokenIterator::addOperator(const std::string& in_value)
{
    if(std::find(registeredOperats.begin(),registeredOperats.end(), in_value) != registeredOperats.end())
        return;

    registeredOperats.push_back(in_value);
}

const Token::type& TokenIterator::next()
{
    auto beginIdx = positionIdx;
    while(source[positionIdx] != '\0')
    {
        auto charIt = source[positionIdx];

        if(charIt == '\n')
        {
            positionIdx++;
            currentLine++;
            continue;
        }

        if(isspace(charIt)) // ignore whitespace
        {
            positionIdx++;
            continue;
        }
        else if(tryTokenizeOperator())
        {
            return currentToken;
        }
        else if(tryTokenizeString())
        {
            return currentToken;
        }
        else if(tryTokenizeNumber())
        {
            return currentToken;
        }
        else if(tryTokenizeLabel())
        {
            return currentToken;
        }
        else
        {
            //TODO: PANIC!
            break;
        }
    }
    currentToken = Token::End{currentLine};
    return currentToken;
}

bool TokenIterator::tryTokenizeNumber()
{
    if(!isdigit(source[positionIdx])) return false;

    std::string summed;
    while(positionIdx != source.size())
    {
        auto charIt = source[positionIdx];

        if(isdigit(charIt) || charIt=='A' || charIt=='B' || charIt=='C' || charIt=='D' || charIt=='E' || charIt=='F'
           || charIt=='a' || charIt=='b' || charIt=='c' || charIt=='d' || charIt=='e' || charIt=='f')
        {
            summed += charIt;
            positionIdx++;
        }
        else if( summed.size() == 1 && charIt == 'x' or charIt == 'b')
        {
            summed += charIt;
            positionIdx++;
        }
        else
        {
            break;
        }
    }

    if(summed[0] == '0') {
        if (summed.size() > 1 && summed[1] == 'x') {
            if (summed.size() == 2)
            {
                currentToken = Token::Number{currentLine,0};
                return true;
            }
            else
            {
                currentToken = Token::Number{currentLine,std::stoi(summed.c_str() + 2, nullptr, 16)};
                return true;
            }
        }
        else if (summed.size() > 1 && summed[1] == 'b') {
            if (summed.size() == 2)
            {
                currentToken = Token::Number{currentLine,0};
                return true;
            }
            else
            {
                currentToken = Token::Number{currentLine,std::stoi(summed.c_str() + 2, nullptr, 2)};
                return true;
            }
        }
        else if (summed.size() == 1)
        {
            currentToken = Token::Number{currentLine,0};
            return true;
        }
        else
        {
            currentToken = Token::Number{currentLine,std::stoi(summed.c_str() + 1, nullptr, 8)};
            return true;
        }
    }

    currentToken = Token::Number{currentLine,std::stoi(summed)};
    return true;
}

bool TokenIterator::tryTokenizeString()
{
    if(source[positionIdx] != '"') return false;

    auto beginIdx = positionIdx;
    positionIdx++;

    while(source[positionIdx] != '\0')
    {
        auto prevCharIt = source[positionIdx-1];
        auto charIt = source[positionIdx];

        if(charIt == '"' && prevCharIt != '\\') // allow escape code
            break;

        positionIdx++;
    }
    positionIdx++; // escape string
    currentToken = Token::String{currentLine,source.substr(beginIdx,positionIdx-beginIdx)};
    return true;
}

bool TokenIterator::tryTokenizeOperator()
{
    auto beginIdx = positionIdx;

    std::string matched {};
    for(auto& operatIt : registeredOperats)
    {
        bool match {true};
        for(int operatCharIdx = 0; operatCharIdx != operatIt.size();operatCharIdx++)
        {
            if(source[beginIdx+operatCharIdx] != operatIt[operatCharIdx])
            {
                match = false;
                break;
            }
        }
        if(!match) continue;
        if(matched.size() < operatIt.size()) matched = operatIt; // keep longer match
    }

    if(matched.empty()) return false;

    positionIdx += matched.size();
    currentToken = Token::Operator{currentLine,matched};
    return true;
}

const Token::type& TokenIterator::current()
{
    return currentToken;
}

bool TokenIterator::tryTokenizeLabel()
{
    if(!((source[positionIdx] >= 'a' && source[positionIdx] <= 'z') || (source[positionIdx] >= 'A' && source[positionIdx] <= 'Z')))
        return false;

    auto beginIdx = positionIdx;
    while(source[positionIdx] != '\0')
    {
        auto charIt = source[positionIdx];

        if ((charIt >= '0' && charIt <= '9') || (charIt >= 'A' && charIt <= 'Z') ||
            (charIt >= 'a' && charIt <= 'z') || charIt == '_')
        {
            positionIdx++;
        } else break;
    }

    currentToken = Token::Label{currentLine,source.substr(beginIdx,positionIdx-beginIdx)};
    return true;
}


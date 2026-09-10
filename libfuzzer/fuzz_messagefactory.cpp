#include <cstddef>
#include <cstdint>
#include <stdexcept>

#include <QByteArray>

#include "messagefactory.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    QByteArray input(
        reinterpret_cast<const char*>(data),
        static_cast<qsizetype>(size)
    );

    try
    {
        Message* message = MessageFactory::createMessage(input);
        delete message;
    }
    catch (const std::runtime_error&)
    {
        // Invalid or unknown message types are expected fuzz inputs.
    }

    return 0;
}

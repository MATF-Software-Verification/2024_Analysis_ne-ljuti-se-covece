#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <memory>

#include <QByteArray>

#include "messagefactory.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    QByteArray input(
        reinterpret_cast<const char*>(data),
        static_cast<qsizetype>(size)
    );

    std::unique_ptr<Message> message;
    try
    {
        message.reset(MessageFactory::createMessage(input));
    }
    catch (const std::runtime_error&)
    {
        // Rejecting arbitrary input is expected; continue with the next input.
        return 0;
    }

    // Failure to parse our own serialized message must not be swallowed.
    const QByteArray serialized = message->prepareMessage();
    std::unique_ptr<Message> reparsed(MessageFactory::createMessage(serialized));

    return 0;
}

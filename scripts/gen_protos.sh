#!/bin/bash

# simple sanity checking for executable
if [ ! -x "$(which protoc)" ]; then
  brew install swift-protobuf
fi

end

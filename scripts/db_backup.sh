#!/bin/sh

# Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -u

TARFILE=$1

echo "Backing up database to $PWD/$TARFILE ..."

docker run --rm \
    -v "$PWD":/host \
    -v spi_db_data:/db_data \
    -w /host \
    ubuntu \
    tar cfz "$TARFILE" /db_data

echo "done."

# don't let tar errors or warnings bubble up
exit 0

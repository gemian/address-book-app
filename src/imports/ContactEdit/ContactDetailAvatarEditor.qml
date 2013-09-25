/*
 * Copyright (C) 2012-2013 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 0.1
import QtContacts 5.0
import Ubuntu.Content 0.1

import "../Common"

ContactDetailBase {
    id: root

    function save() {
        if (root.detail.imageUrl != avatarImage.source) {
            console.debug("Save new image:" + avatarImage.source)
            root.detail.imageUrl = avatarImage.source
            return true
        }
        return false
    }

    detail: contact ? contact.avatar : null
    implicitHeight: units.gu(17)

    Image {
        id: avatarImage

        anchors.fill: parent
        source: root.detail && root.detail.imageUrl != "" ? root.detail.imageUrl : "artwork:/avatar-default.svg"
        asynchronous: true
        fillMode: Image.PreserveAspectCrop

        AbstractButton {
            id: changeButton

            property var activeTransfer

            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: units.gu(1)
            }

            width: units.gu(3)
            height: units.gu(3)

            Image {
                anchors.fill: parent
                source: "artwork:/import-image.svg"
                fillMode: Image.PreserveAspectFit
            }

            onClicked: {
                if (!changeButton.activeTransfer) {
                    changeButton.activeTransfer = ContentHub.importContent(ContentType.Pictures,
                                                                           ContentHub.defaultSourceForType(ContentType.Pictures));
                    changeButton.activeTransfer.start();
                }
            }

            Connections {
                target: changeButton.activeTransfer != null ? changeButton.activeTransfer : null
                onStateChanged: {
                    if (changeButton.activeTransfer.state === ContentTransfer.Charged) {
                        if (changeButton.activeTransfer.items.length > 0) {
                            avatarImage.source = changeButton.activeTransfer.items[0].url;
                        }
                        changeButton.activeTransfer = null
                    }
                }
            }
        }
    }
}


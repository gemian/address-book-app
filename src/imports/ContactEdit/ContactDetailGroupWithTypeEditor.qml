﻿/*
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
import QtContacts 5.0 as QtContacts
import Ubuntu.Components.ListItems 0.1 as ListItem

import "../Common"

ContactDetailGroupWithTypeBase {
    id: root

    property string detailQmlTypeName
    property int currentItem: -1
    property int fieldType: QtContacts.ContactDetail.FieldContext
    property variant placeholderTexts: []

    function save() {
        var changed = false
        for(var i=0; i < detailDelegates.length; i++) {
            var delegate = detailDelegates[i]

            // Get item from Loader
            if (delegate.item) {
                delegate = delegate.item
            }

            if (delegate.save) {
                // save type
                if (updateDetail(delegate.detail, delegate.selectedTypeIndex)) {
                    changed = true
                }

                // save fields
                if (delegate.save()) {
                    changed = true
                }
            }
        }
        return changed
    }
    focus: true
    minimumHeight: units.gu(5)
    headerDelegate: ListItem.Empty {
        id: header
        highlightWhenPressed: false

        width: root.width
        height: units.gu(5)
        // disable listview mouse area
        __mouseArea.visible: false
        Label {
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
                margins: units.gu(2)
            }

            text: root.title

            // style
            fontSize: "medium"
            color: "#f3f3e7"
            opacity: 0.2
        }


        Image {
            anchors {
                verticalCenter: parent.verticalCenter
                right: parent.right
                rightMargin: units.gu(2)
            }
            width: units.gu(3)
            height: units.gu(3)

            source: "artwork:/add-detail.svg"
            fillMode: Image.PreserveAspectFit
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.forceActiveFocus()
                    if (detailQmlTypeName) {
                        var newDetail = Qt.createQmlObject("import QtContacts 5.0; " + detailQmlTypeName + "{}", root)
                        if (newDetail) {
                            root.contact.addDetail(newDetail)
                        }
                    }
                }
            }
        }
    }

    detailDelegate: ContactDetailWithTypeEditor {
        property variant detailType: null
        property bool comboLoaded: false

        function updateCombo(reload)
        {
            // Does not update the combo info after details change (Ex. a new detail field was created)
            if (!reload && comboLoaded) {
                return;
            }

            comboLoaded = true
            var newTypes = []
            for(var i=0; i < root.typeModel.count; i++) {
                newTypes.push(root.typeModel.get(i).label)
            }
            types = newTypes
            if (detail) {
                detailType = getType(detail)
                if (detailType) {
                    selectType(detailType.label)
                }
            }
        }

        placeholderTexts: root.placeholderTexts
        contact: root.contact
        fields: root.fields
        height: implicitHeight
        width: root.width

        onDetailChanged: updateCombo(false)

        // this is necessary due the default property of ListItem.Empty
        Item {
            Connections {
                target: root.typeModel
                onLoaded: updateCombo(true)
            }
        }
    }
}
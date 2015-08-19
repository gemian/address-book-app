/*
 * Copyright (C) 2012-2015 Canonical, Ltd.
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

import QtQuick 2.2
import QtContacts 5.0

import Ubuntu.Components 1.2
import Ubuntu.Components.ListItems 1.0 as ListItem
import Ubuntu.Components.Popups 1.0 as Popups
import Ubuntu.Contacts 0.1 as ContactsUI
import Ubuntu.Content 1.1 as ContentHub

import Ubuntu.AddressBook.Base 0.1
import Ubuntu.AddressBook.ContactShare 0.1

ContactsUI.PageWithBottomEdge {
    id: mainPage
    objectName: "contactListPage"

    property bool pickMode: false
    property alias contentHubTransfer: contactExporter.activeTransfer
    property bool pickMultipleContacts: false
    property QtObject contactIndex: null
    property string newPhoneToAdd: ""
    property alias contactManager: contactList.manager

    readonly property bool isEmpty: (contactList.count === 0)
    readonly property bool allowToQuit: (application.callbackApplication.length > 0)
    readonly property var contactModel: contactList.listModel ? contactList.listModel : null
    readonly property bool searching: (state === "searching" || state === "newphoneSearching")

    // this function is used to reset the contact list page to the default state if it was called
    // from the uri. For example when called to add a new contact
    function returnToNormalState()
    {
        // these two states are the only state that need to be reset
        if (state == "newphoneSearching" || state == "newphone") {
            state = "default"
        }
        application.callbackApplication = ""
    }

    function createContactWithPhoneNumber(phoneNumber)
    {
        var newContact = ContactsJS.createEmptyContact(phoneNumber, mainPage)
        //WORKAROUND: SKD changes the page header as soon as the page get created
        // setting active false will avoid that
        if (bottomEdgeEnabled) {
            mainPage.showBottomEdgePage(Qt.resolvedUrl("ABContactEditorPage.qml"),
                                        {model: contactList.listModel,
                                         contact: newContact,
                                         active: false,
                                         enabled: false,
                                         initialFocusSection: "name"})
        } else {
            pageStack.push(Qt.resolvedUrl("ABContactEditorPage.qml"),
                           {model: contactList.listModel,
                            contact: newContact,
                            initialFocusSection: "name"})
        }
    }

    function showContact(contactId)
    {
        pageStack.push(Qt.resolvedUrl("ABContactViewPage.qml"),
                       {model: contactList.listModel, contactId: contactId})
    }

    function addPhoneToContact(contactId, phoneNumber)
    {
        pageStack.push(Qt.resolvedUrl("ABContactViewPage.qml"),
                       {model: contactList.listModel,
                        contactId: contactId,
                        addPhoneToContact: phoneNumber})
    }

    function importContact(urls)
    {
        if (urls.length > 0) {
            var importDialog = Qt.createQmlObject("VCardImportDialog{}",
                               mainPage,
                               "VCardImportDialog")
            if (importDialog) {
                importDialog.importVCards(contactList.listModel, urls)
            }
        }
    }

    function startPickMode(isSingleSelection, activeTransfer)
    {
        contentHubTransfer = activeTransfer
        pickMode = true
        pickMultipleContacts = !isSingleSelection
        contactList.startSelection()
    }

    function moveListToContact(contact)
    {
        contactIndex = contact
        mainPage.state = "default"
        // this means a new contact was created
        if (mainPage.allowToQuit) {
            application.goBackToSourceApp()
        }
    }

    function addNewPhone(phoneNumber)
    {
        newPhoneToAdd = phoneNumber
        state = "newphone"
        contactList.reset()
    }

    title: i18n.tr("Contacts")
    bottomEdgeTitle: "+"
    bottomEdgeEnabled: !contactList.isInSelectionMode

    flickable: null
    ContactsUI.ContactListView {
        id: contactList
        objectName: "contactListView"
        showImportOptions:  !mainPage.pickMode &&
                            mainPage.newPhoneToAdd === ""
        anchors {
            top: parent.top
            left: parent.left
            bottom: keyboard.top
            right: parent.right
        }
        filterTerm: searchField.text
        multiSelectionEnabled: true
        multipleSelection: (mainPage.pickMode && mainPage.pickMultipleContacts) || !mainPage.pickMode

        onAddContactClicked: mainPage.createContactWithPhoneNumber(label)
        onAddNewContactClicked: mainPage.createContactWithPhoneNumber(mainPage.newPhoneToAdd)

        onContactClicked: {
            mainPage.state = "default"
            pageStack.push(Qt.resolvedUrl("ABContactViewPage.qml"),
                           {model: contactList.listModel,
                            contact: contact})
        }
        onIsInSelectionModeChanged: mainPage.state = isInSelectionMode ? "selection"  : "default"
        onSelectionCanceled: {
            if (pickMode) {
                if (contentHubTransfer) {
                    contentHubTransfer.state = ContentHub.ContentTransfer.Aborted
                }
                pickMode = false
                contentHubTransfer = null
                application.returnVcard("")
            }
            mainPage.state = "default"
        }

        onError: pageStack.contactModelError(error)
    }

    TextField {
        id: searchField

        anchors {
            left: parent.left
            right: parent.right
            rightMargin: units.gu(2)
        }
        visible: mainPage.searching
        onTextChanged: contactList.currentIndex = -1
        inputMethodHints: Qt.ImhNoPredictiveText
        placeholderText: i18n.tr("Search...")
    }

    Connections {
        target: mainPage.head.sections
        onSelectedIndexChanged: {
            switch (mainPage.head.sections.selectedIndex) {
            case 0:
                contactList.showAllContacts()
                break;
            case 1:
                contactList.showFavoritesContacts()
                break;
            default:
                break;
            }
        }
    }

    state: "default"
    states: [
        PageHeadState {
            id: defaultState

            name: "default"
            backAction: Action {
                visible: mainPage.allowToQuit
                iconName: "back"
                text: i18n.tr("Quit")
                onTriggered: {
                    application.goBackToSourceApp()
                    mainPage.returnToNormalState()
                }
            }
            actions: [
                Action {
                    text: i18n.tr("Search")
                    iconName: "search"
                    visible: !mainPage.isEmpty
                    onTriggered: {
                        mainPage.state = (mainPage.state === "newphone" ? "newphoneSearching" : "searching")
                        contactList.showAllContacts()
                        searchField.forceActiveFocus()
                    }
                },
                Action {
                    visible: buteoImporter.active || (application.isOnline && contactList.syncEnabled)
                    text: contactList.syncing ? i18n.tr("Syncing") : i18n.tr("Sync")
                    iconName: "reload"
                    enabled: !contactList.syncing
                    onTriggered: {
                        if (buteoImporter.active) {
                            buteoImporter.item.start()
                        } else {
                            contactList.sync()
                        }
                    }
                },
                Action {
                    text: i18n.tr("Settings")
                    iconName: "settings"
                    onTriggered: pageStack.push(Qt.resolvedUrl("./Settings/SettingsPage.qml"),
                                                {"contactListModel": contactList.listModel})
                }
            ]
            PropertyChanges {
                target: mainPage.head
                backAction: defaultState.backAction
                actions: defaultState.actions
                // TRANSLATORS: this refers to all contacts
                sections.model: [i18n.tr("All"), i18n.tr("Favorites")]
            }
            PropertyChanges {
                target: searchField
                text: ""
            }
        },
        PageHeadState {
            id: searchingState

            name: "searching"
            backAction: Action {
                iconName: "back"
                text: i18n.tr("Cancel")
                onTriggered: {
                    contactList.forceActiveFocus()
                    mainPage.head.sections.selectedIndex = 0
                    mainPage.state = (mainPage.state === "newphoneSearching" ? "newphone" : "default")
                }
            }

            PropertyChanges {
                target: mainPage.head
                backAction: searchingState.backAction
                contents: searchField
            }

            PropertyChanges {
                target: searchField
                text: ""
            }
        },
        PageHeadState {
            id: selectionState

            name: "selection"
            backAction: Action {
                text: i18n.tr("Cancel selection")
                iconName: "back"
                onTriggered: contactList.cancelSelection()
            }
            actions: [
                Action {
                    text: (contactList.selectedItems.count === contactList.count) ? i18n.tr("Unselect All") : i18n.tr("Select All")
                    iconName: "select"
                    onTriggered: {
                        if (contactList.selectedItems.count === contactList.count) {
                            contactList.clearSelection()
                        } else {
                            contactList.selectAll()
                        }
                    }
                    visible: contactList.multipleSelection && !mainPage.isEmpty
                },
                Action {
                    objectName: "share"
                    text: i18n.tr("Share")
                    iconName: mainPage.pickMode ? "tick" : "share"
                    enabled: (contactList.selectedItems.count > 0)
                    visible: contactList.isInSelectionMode
                    onTriggered: {
                        var contacts = []
                        var items = contactList.selectedItems

                        for (var i=0, iMax=items.count; i < iMax; i++) {
                            contacts.push(items.get(i).model.contact)
                        }
                        contactExporter.start(contacts)
                        contactList.endSelection()
                    }
                },
                Action {
                    objectName: "delete"
                    text: i18n.tr("Delete")
                    iconName: "delete"
                    enabled: (contactList.selectedItems.count > 0)
                    visible: contactList.isInSelectionMode && !mainPage.pickMode
                    onTriggered: {
                        var contacts = []
                        var items = contactList.selectedItems

                        for (var i=0, iMax=items.count; i < iMax; i++) {
                            contacts.push(items.get(i).model.contact)
                        }

                        var dialog = PopupUtils.open(removeContactDialog, null)
                        dialog.contacts = contacts
                        contactList.endSelection()
                    }
                }
            ]
            PropertyChanges {
                target: mainPage.head
                backAction: selectionState.backAction
                actions: selectionState.actions
            }
            PropertyChanges {
                target: mainPage
                bottomEdgeEnabled: false
                title: " "
            }
        },
        PageHeadState {
            name: "newphone"
            extend: "default"
            head: mainPage.head
            PropertyChanges {
                target: contactList
                showAddNewButton: true
            }
            PropertyChanges {
                target: mainPage
                bottomEdgeEnabled: false
                title: i18n.tr("Add contact")
            }
            PropertyChanges {
                target: contactList
                detailToPick: -1
            }
        },
        PageHeadState {
            name: "newphoneSearching"
            extend: "searching"
            head: mainPage.head
            PropertyChanges {
                target: contactList
                detailToPick: -1
                showAddNewButton: true
            }
            PropertyChanges {
                target: mainPage
                bottomEdgeEnabled: false
            }
        }
    ]
    onActiveChanged: {
        if (active && contactList.showAddNewButton) {
            contactList.positionViewAtBeginning()
        }
    }

    // We need to reset the page proprerties in case of the page was created pre-populated,
    // with phonenumber or contact.
    onBottomEdgeDismissed: {
        //WORKAROUND: SKD changes the page header as soon as the page get created
        // setting active false will avoid that
        var newContact = ContactsUI.ContactsJS.createEmptyContact("", mainPage)
        mainPage.setBottomEdgePage(Qt.resolvedUrl("ABContactEditorPage.qml"),
                                   {model: contactList.listModel,
                                    contact: newContact,
                                    active: false,
                                    enabled: false,
                                    initialFocusSection: "name"})
    }

    KeyboardRectangle {
        id: keyboard
    }

    Column {
        id: emptyStateScreen

        anchors.centerIn: parent
        height: childrenRect.height
        width: childrenRect.width
        spacing: units.gu(2)
        visible: (!contactList.busy &&
                  !contactList.favouritesIsSelected &&
                  mainPage.isEmpty &&
                  (mainPage.newPhoneToAdd === "") &&
                  !(contactList.filterTerm && contactList.filterTerm !== ""))

        Behavior on visible {
            SequentialAnimation {
                 PauseAnimation {
                     duration: !emptyStateScreen.visible ? 500 : 0
                 }
                 PropertyAction {
                     target: emptyStateScreen
                     property: "visible"
                 }
            }
        }

        Icon {
            id: emptyStateIcon
            anchors.horizontalCenter: emptyStateLabel.horizontalCenter
            height: units.gu(5)
            width: units.gu(5)
            opacity: 0.3
            name: "contact"
        }
        Label {
            id: emptyStateLabel
            width: mainPage.width - units.gu(12)
            height: paintedHeight
            text: mainPage.pickMode ?
                      i18n.tr("You have no contacts.") :
                      i18n.tr("Create a new contact by swiping up from the bottom of the screen.")
            color: "#5d5d5d"
            fontSize: "x-large"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Connections {
        target: mainPage.contactModel
        onContactsChanged: {
            if (contactIndex) {
                contactList.positionViewAtContact(mainPage.contactIndex)
                mainPage.contactIndex = null
            }
        }
    }

    ContactExporter {
        id: contactExporter

        contactModel: contactList.listModel
        exportToDisk: mainPage.pickMode
        onDone: {
            mainPage.pickMode = false
            mainPage.state = "default"
            application.returnVcard(outputFile)
        }

        onContactsFetched: {
            // Share contacts to an application chosen by the user
            if (!mainPage.pickMode) {
                contactExporter.dismissBusyDialog()
                pageStack.push(contactShareComponent,
                               { contactModel: contactExporter.contactModel,
                                 contacts: contacts })
            }
        }
    }

    Component {
        id: removeContactDialog

        RemoveContactsDialog {
            id: removeContactsDialogMessage

            onCanceled: {
                PopupUtils.close(removeContactsDialogMessage)
            }

            onAccepted: {
                removeContacts(contactList.listModel)
                PopupUtils.close(removeContactsDialogMessage)
            }
        }
    }

    Component {
        id: contactShareComponent

        ContactSharePage {
            objectName: "contactSharePage"
        }
    }

    Loader {
        id: buteoImporter

        asynchronous: true
        source: Qt.resolvedUrl("ButeoImportDialog.qml")
        active: !mainPage.pickMode && item && item.dismiss ? false : true
    }

    Component.onCompleted: {
        application.elapsed()
        if ((typeof(TEST_DATA) !== "undefined") && (TEST_DATA !== "")) {
            contactList.listModel.importContacts("file://" + TEST_DATA)
        }

        mainPage.setBottomEdgePage(Qt.resolvedUrl("ABContactEditorPage.qml"),
                                   {model: contactList.listModel,
                                    contact: ContactsUI.ContactsJS.createEmptyContact("", mainPage),
                                    active: false,
                                    enabled: false,
                                    initialFocusSection: "name"})

        if (pageStack) {
            pageStack.contactListPage = mainPage
        }
    }
}

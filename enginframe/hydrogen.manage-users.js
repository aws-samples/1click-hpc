/*global jQuery, hydrogenConf, document, window, location, wordcloud */
/*
 * Copyright 1999-2021 by Nice, srl.,
 * Via Milliavacca 9, Asti, 14020, Italy
 * All rights reserved.
 *
 * This software is the confidential and proprietary information
 * of Nice, srl. ("Confidential Information"). You
 * shall not disclose such Confidential Information and shall use
 * it only in accordance with the terms of the license agreement
 * you entered into with Nice.
 */
// The code depends from wordcloud/dynacloud plugin

var manageUsers = {
    refresh: function () {
        jQuery('#manage-users-table').hytable('reload');
    },

    init: function (id) {
        jQuery(document).ready(function () {
            var msg, toolbar, table, filters, projects, box, basefilter, sdf, namespace;
            var currentFilter = '';
            var currentView = '';

            msg = jQuery('#' + id + '-message').hymessage();

            box = jQuery('#' + id + '-wrapper').collapsibleBox({
                cookieNamePrefix: id + '-box'
            });

            toolbar = jQuery('#' + id + '-toolbar').hytoolbar({
                conf: hydrogenConf[id],
                searchBoxHint: 'Search'
            });

            table = jQuery('#' + id + '-table').hytable({
                xmlreader: {
                    root: 'users',
                    row: 'user',
                    page: 'users>page',
                    total: 'users>total',
                    records: 'users>records',
                    repeatitems: false,
                    id: 'user>userName'
                },
                conf: hydrogenConf[id],
                messageArea: msg,
                defaultFilter: basefilter,
                defaultLoadErrorMessage: 'Cannot obtain the list of Users from the server.'
            });

            // Filters - begin
            filters = jQuery('#' + id + '-filters').hyfilters({
                conf: hydrogenConf[id]
            });
            // bind of 'hyfiltersselect' done by wordcloud plugin
            // Filters - end

            table.bind('hytablegridcomplete', function () {
                jQuery('td>div.hy-star').toggleStar();
            });

            // bind of 'hytableaction' done by wordcloud plugin

            table.bind('hytableselectionchanged', function (e, data) {
                toolbar.hytoolbar('viewProperties', {
                    'selected': table.hytable('selected').length
                });
            });

            // bind of 'hytoolbaraction' done by wordcloud plugin
            // bind of 'hytoolbarsearch' done by wordcloud plugin

            jQuery.hydrogen.setupAutoRefresh(id, hydrogenConf, manageUsers.refresh);

            wordcloud.init({
                title: 'Groups',
                tableVar: 'manageUsers',
                widgetId: id,
                toolbar: toolbar,
                table: table,
                filters: filters,
                searchCols: [ 'userName', 'realName', 'groups' ],
                filterKey: 'groups',
                refreshFunc: function () {
                    jQuery.enginframe.invokeService({
                        sdf: '/' + jQuery.enginframe.rootContext + '/applications/applications.admin.xml',
                        uri: '//com.enginframe.user-group-manager/list.groups',
                        dataType: "xml",
                        data: {
                            namespace: 'applications'
                        },
                        success: function (xml) {
                            var data = '';
                            jQuery(xml).find('ugm\\:group, group').each(function () {
                                var name = jQuery(this).attr("name");
                                if (name !== "all-users" && name !== "admin") {
                                    var users = jQuery(this).attr("users");
                                    jQuery.each(users.split(","), function () {
                                        if (data !== '') {
                                            data += '\n';
                                        }
                                        data += name;
                                    });
                                }
                            });
                            wordcloud.setData(data);
                        }
                    });
                }
            });
        });
    },

    formatter: {
        groups: function (val, opt, row) {
            var i, userGroups, formattedGroups, encName;

            if (typeof val === 'undefined') {
                val = "";
            }
            else {
                userGroups = val.split(",");
                formattedGroups = [];
                for (i = 0; i < userGroups.length; i++) {
                    if (userGroups[i] !== "admin") {
                        encName = efEncodeHtml(userGroups[i]);
                        formattedGroups.push("<div class='ef-service-group-tag' title='" + encName + "'>" + encName + "</div>");
                    }
                }
                val = formattedGroups.join("");
            }
            return "<div class='applications-groups-list'>" + val + "</div>";
        },
        lastLoginTime: function (val, opt, row)  {
            var lastLoginTime = jQuery(jQuery.hydrogen.prettyDateFormatter(val, opt)).removeAttr('abbr').text();
            return "<div>" + lastLoginTime + " </div>";
        },
        creationTime: function (val, opt, row)  {
            var creationTime = jQuery(jQuery.hydrogen.prettyDateFormatter(val, opt)).removeAttr('abbr').text();
            return "<div>" + creationTime + " </div>";
        },
        isAdmin: function (val, opt, row) {
            var efAdminClass;
            var tooltip = "Applications Admin";
            if (jQuery(row).attr("isEFAdmin") === "true") {
                efAdminClass = "fa-check-efadmin";
                tooltip = "EnginFrame Admin";
            }
            if (val === "true") {
                return "<div class='ef-ugm-admin-user' title='" + tooltip + "'><i class='fa fa-check " + efAdminClass + "' /></div>";
            }
            else {
                return "<div/>";
            }
        }
    },

    goRegisterUser: function () {
        var sdf, uri, msg, message, dialogTitle, buttonLabel;

        dialogTitle = "Add User";
        buttonLabel = "Add";
        msg = jQuery('#manage-users-message').hymessage();

        manageUsers.editUserDialog(dialogTitle, buttonLabel, false, "", "", "", false, false, "", function (userName, password, re_password, realName, groups) {
            jQuery.hydrogen.invokeService({
                sdf: '/' + jQuery.enginframe.rootContext + '/applications/applications.admin.xml',
                uri: '//com.enginframe.user-group-manager/add.user',
                data: {
                    userName: userName,
                    password: password,
                    re_password: re_password,
                    realName: realName,
                    groups: groups,
                    namespace: 'applications'
                },
                success: function (xml) {
                    manageUsers.refresh();
                },
                messagebox: msg
            });
        });
    },

    goEdit: function (oldUserName, oldRealName, oldIsAdmin, isEFAdmin, oldGroups, actor) {
        var sdf, uri, msg, message, dialogTitle, buttonLabel;

        dialogTitle = "Edit User: " + oldUserName;
        buttonLabel = "Save";
        msg = jQuery('#manage-users-message').hymessage();

        manageUsers.editUserDialog(dialogTitle, buttonLabel, true, actor, oldUserName, oldRealName, oldIsAdmin, isEFAdmin, oldGroups, function (userName, realName, groups) {
            jQuery.hydrogen.invokeService({
                sdf: '/' + jQuery.enginframe.rootContext + '/applications/applications.admin.xml',
                uri: '//com.enginframe.user-group-manager/edit.user',
                data: {
                    userName: userName,
                    newRealName: realName,
                    newGroups: groups,
                    namespace: 'applications'
                },
                success: function (xml) {
                    manageUsers.refresh();
                },
                messagebox: msg
            });
        });
    },

    goImportUsers: function () {
        var sdf, uri, msg, message, namespace, inputLabel;

        msg = jQuery('#manage-users-message').hymessage();
        inputLabel = "<p>Upload a CSV compliant file or insert a CSV compliant text containing the User list.</p>" +
                     "<p>The CSV to define users is like the following examples:</p>" +
                     "<p>username1,realname1,group1<br/>" +
                     "username2,,group1,group2<br/>" +
                     "username3,,</p>" +
                     "<p>Where:<br/>" +
                     "- first field is the User Name (required)<br/>" +
                     "- second field is the Real Name (required but can be empty)<br/>" +
                     "- third and following fields are the Groups (optional)</p>";

        manageUsers.importUsersDialog("Import Users", inputLabel, "Import", true, function (formId) {
            jQuery("#" + formId).ajaxSubmit({
                    url: '/' + jQuery.enginframe.rootContext + '/applications/applications.admin.xml' + '?_uri=//com.enginframe.user-group-manager/add.users',
                    type: 'POST',
                    data: {
                        namespace: 'applications'
                    },
                    dataType: 'xml',
                    success: function (responseXML, statusText, xhr) {
                        msg.css('white-space', 'pre-wrap');
                        msg.hymessage('info', jQuery(responseXML).find('ef\\:message, message').text(), 5000);
                        manageUsers.refresh();
                    },
                    error: function (xhr, statusText, errorThrown) {
                        msg.css('white-space', 'pre-wrap');
                        msg.hymessage('alert', jQuery(xhr.responseText).find('ef\\:message, message').text(), 15000);
                        manageUsers.refresh();
                    }
            }).clearForm();
        });
    },

    //------ TagIt Utility ------ //
    tagIt: function (divId, className, placeholder, autocompleteOnFocus, autocompleteServiceUri) {
        var sdf, namespace, input, uniqueTags, uniqueHostTags;
        //The text input
        input = jQuery("input" + divId);

        // remove the Hydrogen old tagit style
        jQuery("link[href*='tagit-stylish-yellow.css']").remove();

        input.tagit({
            placeholderText: placeholder,
            //availableTags: availableTags,
            removeConfirmation: true,
            caseSensitive: false,
            showAutocompleteOnFocus: autocompleteOnFocus,
            autocomplete: ({
                source: function (request, response) {
                    jQuery.hydrogen.invokeService({
                        sdf: '/' + jQuery.enginframe.rootContext + '/applications/applications.admin.xml',
                        uri: autocompleteServiceUri,
                        data: {
                            namespace: 'applications'
                        },
                        success: function (xml) {
                            var data = '';
                            jQuery(xml).find('ugm\\:group, group').each(function () {
                                if (data !== '') {
                                    data += '\n';
                                }
                                var name = jQuery(this).attr("name");
                                if (name !== "all-users" && name !== "admin") {
                                    data += name;
                                }
                            });

                            var matcherTag = new RegExp("^" + jQuery.ui.autocomplete.escapeRegex(request.term), "i");
                            var rawTags = data.split("\n");
                            var availableTags = [];
                            uniqueTags = [];

                            for (var i = 0; i < rawTags.length; i++) {
                                // Remove duplicates and empty string
                                if (uniqueTags.indexOf(rawTags[i]) < 0 && rawTags[i]) {
                                    uniqueTags.push(rawTags[i]);

                                    // Match only the beginning of terms
                                    if (matcherTag.test(rawTags[i])) {
                                        availableTags.push(rawTags[i]);
                                    }
                                }
                            }
                            response(availableTags);
                        },
                        dataType: 'xml'
                    });
                }
            })
        }).addClass(className);
    },

    // ------ TagIt Dialog ------ //
    tagItDialog: function (dialogTitle, inputLabel, buttonLabel, oldValue, check, autocompleteServiceUri, actionfunc) {
        var dialog, dialogId, inputId, entry, button, dialogButtons, warningBox;

        if (/^[a-zA-Z0-9- ]*$/.test(oldValue) && jQuery(oldValue).is("div")) {
            oldValue = jQuery(oldValue).text();
        }
        dialogId = Math.floor(Math.random() * 1000) + 1;
        inputId = 'input_' + dialogId;
        dialog = jQuery('<div class="hy-tagit-dialog" id="' + dialogId + '"/>').appendTo(jQuery('body'));
        jQuery('<label for="' + inputId + '" style="display:block">' + inputLabel + ':</label>').appendTo(dialog);
        entry = jQuery('<input type="text" name="value" id="' + inputId + '"/>').appendTo(dialog);
        entry.val(oldValue);
        manageUsers.tagIt("#" + inputId, "tags", "", false, autocompleteServiceUri);

        warningBox = jQuery('<div class="ui-state-error ui-corner-all ef-ugm-reserved-group ui-helper-hidden"><table width="100%"><tbody><tr><td><span class="ui-icon ui-icon-alert"/></td><td width="99%"><span class="msgErr"/></td></tr></tbody></table></div>').appendTo(dialog);

        jQuery("#" + inputId).tagit({
            beforeTagAdded: function (event, ui) {
                if (ui.tagLabel === "admin" || ui.tagLabel === "all-users") {
                    jQuery(".ef-ugm-reserved-group span.msgErr").text("Group " + ui.tagLabel + " is reserved!");
                    jQuery(".ef-ugm-reserved-group").removeClass("ui-helper-hidden");
                    return false;
                }
                else if (!(new RegExp('^[\\w.-]+$')).test(ui.tagLabel)) {
                    jQuery(".ef-ugm-reserved-group span.msgErr").text("Invalid character for group name!");
                    jQuery(".ef-ugm-reserved-group").removeClass("ui-helper-hidden");
                    return false;
                }
                else {
                    jQuery(".ef-ugm-reserved-group").addClass("ui-helper-hidden");
                }
            }
        });

        dialogButtons = {
            Cancel: function () {
                jQuery(this).dialog("close");
            }
        };
        dialogButtons[buttonLabel] = function () {
            var newValue = entry.val();
            if (check === true) {
                if (newValue.length <= 0) {
                    return false;
                }
            }
            jQuery(this).dialog("close");
            actionfunc(newValue);
        };

        dialog.dialog({
            title: dialogTitle,
            resizable: false,
            buttons: dialogButtons,
            modal: true,
            width: "450px"
        });

        button = jQuery('button:contains(' + buttonLabel + ')', dialog.parent('div.ui-dialog'));
        button.addClass('ui-priority-primary');
        entry.keypress(function (e) {
            if (e.which === 13) {
                button.click();
                return false;
            }
            return true;
        });
    },

    goEditGroups: function (userNames) {
        var msg, inputLabel, autocompleteServiceUri, sdf, namespace;

        msg = jQuery('#manage-users-message').hymessage();
        inputLabel = "Specify the common Groups to set for the selected Users";
        autocompleteServiceUri = '//com.enginframe.user-group-manager/list.groups';

        jQuery.hydrogen.invokeService({
            sdf: '/' + jQuery.enginframe.rootContext + '/applications/applications.admin.xml',
            uri: '//com.enginframe.user-group-manager/list.common.groups',
            data: {
                userNames: userNames,
                namespace: 'applications'
            },
            success: function (xml) {
                var data = '';
                jQuery(xml).find('ugm\\:group, group').each(function () {
                    var name = jQuery(this).attr("name");
                    if (name !== "admin") {
                        if (data !== '') {
                            data += ',';
                        }
                        data += name;
                    }
                });
                var oldValue = data;

                manageUsers.tagItDialog("Edit Groups", inputLabel, "Save", oldValue, false, autocompleteServiceUri, function (newGroups) {
                    jQuery.hydrogen.invokeService({
                        sdf: '/' + jQuery.enginframe.rootContext + '/applications/applications.admin.xml',
                        uri: '//com.enginframe.user-group-manager/set.users.to.common.groups',
                        data: {
                            userNames: userNames,
                            oldGroups: oldValue,
                            newGroups: newGroups,
                            namespace: 'applications'
                        },
                        success: function (xml) {
                            manageUsers.refresh();
                        },
                        messagebox: msg
                    });
                });
            }
        });
    },

    goEditGroupsPre: function (environment) {
        var userNames = environment["%SELECTED_IDS%"];
        manageUsers.goEditGroups(userNames);
    },

    editUserDialog: function (dialogTitle, buttonLabel, isEdit, actor, oldUserName, oldRealName, oldIsAdmin, isEFAdmin, oldGroups, actionfunc) {
        var dialog, button, dialogButtons, warningBox;
        var userNameEntry, passwordEntry, re_passwordEntry, realNameEntry, isAdminLabel, isAdminEntry, filteredGroups, groupsInputId, groupsEntry;

        dialog = jQuery('<div class="ef-manage-user-dialog hy-simple-input-dialog"/>').appendTo(jQuery('body'));
        jQuery('<div class="ef-manage-user-dialog-message" style="display:none;" />').appendTo(dialog);

        if (!isEdit) {
            jQuery('<label for="user-name" style="display:block">User Name:</label>').appendTo(dialog);
            userNameEntry = jQuery('<input type="text" name="user-name" id="user-name"/>').appendTo(dialog);
            jQuery('<label for="password" style="display:block">Password:</label>').appendTo(dialog);
            passwordEntry = jQuery('<input type="password" name="password" id="password"/>').appendTo(dialog);
            jQuery('<label for="re_password" style="display:block">Re-Password:</label>').appendTo(dialog);
            re_passwordEntry = jQuery('<input type="password" name="re_password" id="re_password"/>').appendTo(dialog);
        }

        jQuery('<label for="real-name" style="display:block">Real Name:</label>').appendTo(dialog);
        realNameEntry = jQuery('<input type="text" name="real-name" id="real-name"/>').appendTo(dialog);
        if (isEdit) {
            realNameEntry.val(oldRealName);
        }

        isAdminLabel = jQuery('<label for="is-admin" style="display:block">Administrator:</label>').appendTo(dialog);
        isAdminEntry = jQuery('<input type="checkbox" name="is-admin" id="is-admin" value="admin"/>').appendTo(isAdminLabel);

        filteredGroups = oldGroups;
        if (isEdit && oldIsAdmin === "true") {
            isAdminEntry.prop('checked', true);
            filteredGroups = oldGroups.split(',').filter(function (currentValue) {
                // admin group is managed by the checkbox
                return currentValue != "admin";
            }).join();
        }

        if (isEdit && ((actor && actor === oldUserName) || isEFAdmin === "true")) {
            isAdminEntry.prop('disabled', true);
        }

        groupsInputId = 'groups_' + Math.floor(Math.random() * 1000) + 1;
        jQuery('<label for="' + groupsInputId + '" style="display:block">Groups:</label>').appendTo(dialog);
        groupsEntry = jQuery('<input type="text" name="groups" id="' + groupsInputId + '"/>').appendTo(dialog);
        if (isEdit) {
            groupsEntry.val(filteredGroups);
        }

        manageUsers.tagIt("#" + groupsInputId, "groups", "", false, '//com.enginframe.user-group-manager/list.groups');

        warningBox = jQuery('<div class="ui-state-error ui-corner-all ef-ugm-reserved-group ui-helper-hidden">' +
                '<table width="100%"><tbody><tr><td><span class="ui-icon ui-icon-alert"/></td><td width="99%"><span class="msgErr"/></td></tr></tbody></table>' +
            '</div>').appendTo(dialog);

        jQuery("#" + groupsInputId).tagit({
            beforeTagAdded: function (event, ui) {
                if (ui.tagLabel === "admin" || ui.tagLabel === "all-users") {
                    jQuery(".ef-ugm-reserved-group span.msgErr").text("Group " + ui.tagLabel + " is reserved!");
                    jQuery(".ef-ugm-reserved-group").removeClass("ui-helper-hidden");
                    return false;
                }
                else if (!(new RegExp('^[\\w.-]+$')).test(ui.tagLabel)) {
                    jQuery(".ef-ugm-reserved-group span.msgErr").text("Invalid character for group name!");
                    jQuery(".ef-ugm-reserved-group").removeClass("ui-helper-hidden");
                    return false;
                }
                else {
                    jQuery(".ef-ugm-reserved-group").addClass("ui-helper-hidden");
                }
            }
        });

        dialogButtons = {
            Cancel: function () {
                jQuery(this).dialog("close");
            }
        };
        dialogButtons[buttonLabel] = function () {
            var userName, password, re_password, realName, groups, sdf, namespace;

            if (!isEdit) {
                userName = userNameEntry.val();
                password = passwordEntry.val();
                re_password = re_passwordEntry.val();
                if (userName.length <= 0) {
                    jQuery('.ef-manage-user-dialog-message').hymessage().hymessage('alert', "User Name cannot be empty");
                    return false;
                }
                if (!/^[_a-zA-Z0-9][_a-zA-Z0-9.@\-]*$/.test(userName)) {
                    jQuery('.ef-manage-user-dialog-message').hymessage().hymessage('alert', "Invalid User Name: Allowed characters are letters, digits or one of _ . - @");
                    return false;
                }
                if (password != re_password) {
                    jQuery('.ef-manage-user-dialog-message').hymessage().hymessage('alert', "You entered two different password.");
                    return false;
                }
                
                

                
            }
            else {
                userName = oldUserName;
            }
            realName = realNameEntry.val();
            groups = groupsEntry.val();

            jQuery(this).dialog("close");

            // add group admin if checkbox Administrator is checked
            if (jQuery(isAdminEntry).is(':checked')) {
                if (groups) {
                    groups += ",admin";
                }
                else {
                    groups += "admin";
                }
            }
            actionfunc(userName, password, re_password, realName, groups);
        };

        dialog.dialog({
            title: dialogTitle,
            resizable: false,
            buttons: dialogButtons,
            modal: true
        });

        button = jQuery('button:contains(' + buttonLabel + ')', dialog.parent('div.ui-dialog'));
        button.addClass('ui-priority-primary');

        if (!isEdit) {
            userNameEntry.keypress(function (e) {
                if (e.which === 13) {
                    button.click();
                    return false;
                }
                return true;
            });
        }

        realNameEntry.keypress(function (e) {
            if (e.which === 13) {
                button.click();
                return false;
            }
            return true;
        });

        groupsEntry.keypress(function (e) {
            if (e.which === 13) {
                button.click();
                return false;
            }
            return true;
        });
    },

    importUsersDialog: function (dialogTitle, dialogDescription, buttonLabel, checkEmpty, actionfunc) {
        var dialog, form, entryTextArea, entryFile, button, dialogButtons;

        dialog = jQuery(".hy-import-users-dialog");
        if (dialog.length === 0) {
            dialog = jQuery('<div class="hy-import-users-dialog"/>').appendTo(jQuery('body'));
            jQuery('<div style="display:block">' + dialogDescription + '</div>').appendTo(dialog);
            form = jQuery('<form id="import-users-form"/>').appendTo(dialog);
            jQuery('<input type="file" name="fileCSV" id="file-csv" />').appendTo(form);
            jQuery('<div style="display:block"><p></p></div>').appendTo(form);
            jQuery('<textarea name="usersCSV" id="users-csv" class="ef-ugm-dialog-input-area" rows="10" cols="50"/>').appendTo(form);
        }

        dialogButtons = {
            Cancel: function () {
                jQuery(this).dialog("close");
            }
        };
        dialogButtons[buttonLabel] = function () {
            var entryFile = jQuery("#file-csv").val();
            var entryTextArea = jQuery("#users-csv").val();

            if (checkEmpty === true) {
                if (entryFile.length === 0 && entryTextArea.length === 0) {
                    return false;
                }
            }
            jQuery(this).dialog("close");

            actionfunc("import-users-form");
        };

        dialog.dialog({
            title: dialogTitle,
            resizable: false,
            buttons: dialogButtons,
            modal: true,
            width: "550px"
        });

        button = jQuery('button:contains(' + buttonLabel + ')', dialog.parent('div.ui-dialog'));
        button.addClass('ui-priority-primary');
    }
};
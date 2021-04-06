<?xml version="1.0" encoding="utf-8"?>

<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:ef="http://www.enginframe.com/2000/EnginFrame"
                xmlns:efx="xalan://com.enginframe.xslt.xalan.Extensions"
                xmlns:efactions="http://www.enginframe.com/2000/efactions"
                xmlns:exsl="http://exslt.org/common"
                xmlns:encode="org.owasp.encoder.Encode"
                extension-element-prefixes="efx exsl"
                exclude-result-prefixes="ef efx exsl efactions encode">

<!--
 * Copyright 1998-2021 by Nice, srl.,
 * Via Milliavacca, 9
 * 14100 Asti - ITALY
 * All rights reserved.
 *
 * This software is the confidential and proprietary information
 * of Nice, srl. ("Confidential Information").  You
 * shall not disclose such Confidential Information and shall use
 * it only in accordance with the terms of the license agreement
 * you entered into with Nice.
-->


  <!-- Configuration variables (nj namespace)-->
  
  <!-- Right (hydrogen filters/charts) column width in pixel. Default: 200 -->
  <xsl:variable name="nj.right.column.width">200</xsl:variable>

  <xsl:variable name="nj.navigation.title">
    <xsl:value-of select="/ef:agent/descendant::ef:folder[@id=$ef.navigation.root]/ef:name"/>
  </xsl:variable>

  <!-- HTML Title (default: agent name) -->
  <xsl:variable name="nj.title" select="$agent_name"/>

  <!-- Logo displayed in the top banner -->
  <xsl:variable name="nj.logo.href" select="concat('/', $_root_context)"/>

  <!-- Title displayed in the top banner -->
  <xsl:variable name="nj.headline"/>

  <!-- Show admin portal link near the logout link for admin users -->
  <xsl:variable name="nj.show.admin.link" select="true()"/>
  <xsl:variable name="nj.portal.icon"><i class="fa fa-gear"></i></xsl:variable>
  <xsl:variable name="nj.ext.portal.uri" select="$nj_admin_uri"/>
  <xsl:variable name="nj.ext.portal.name">Administration</xsl:variable>

  <!-- Show interactive settings link near the logout link  -->
  <xsl:variable name="nj.show.interactive.settings.link" select="true()"/>
  <xsl:variable name="nj.interactive.settings.uri" select="$nj_interactive_settings_uri"/>
  <xsl:variable name="nj.interactive.settings.name">Settings</xsl:variable>
  
  <xsl:variable name="nj.change.password.uri" select="$nj_change_password_uri"/>
  <xsl:variable name="nj.change.password.name">Change Password</xsl:variable>

  <!-- Favicon -->
  <xsl:variable name="nj.favicon" select="concat('/', $_root_context, '/images/favicon.ico')"/>

  <!-- Login service uri -->
  <xsl:variable name="nj.login.uri"/>

  <!-- Logout service uri -->
  <xsl:variable name="nj.logout.uri" select="concat($agent,'.xml?_uri=//com.enginframe.system/logout')"/>

  <!-- Footer logo -->
  <xsl:variable name="nj.footer.logo" select="concat($nj_img, '/NICE_logo.gif')"/>
  <xsl:variable name="nj.footer.logo.href">https://www.nice-software.com</xsl:variable>

  <!-- EF Version -->
  <xsl:variable name="nj.ef.version">
    EnginFrame Version 2020 - Copyright &#169; 1998 - 2021 NICE s.r.l.
  </xsl:variable>

  <!-- Copyright message -->
  <xsl:variable name="nj.copyright">
    <a href="{$nj.footer.logo.href}" title="Go to www.nice-software.com" target="_blank">www.nice-software.com</a>
    All trademarks and logos on this page are owned by NICE s.r.l. or by their respective owners.
  </xsl:variable>

  <xsl:variable name="nj.login.copyright">
    <a href="{$nj.footer.logo.href}" title="Go to www.nice-software.com" target="_blank">www.nice-software.com</a><br/>
    All trademarks and logos on this page are owned <br />by NICE s.r.l. or by their respective owners.
  </xsl:variable>

  <!-- Credits -->
  <xsl:variable name="nj.credits.href" select="concat('/', $_root_context, '/legalnotices.txt')"/>

  <xsl:variable name="nj.credits">
    <a href="{$nj.credits.href}" title="NICE EnginFrame Legal Notices" target="_blank">Legal Notices</a>
  </xsl:variable>

  <!-- Private variables -->

  <!-- store current user login in variable -->
  <xsl:variable name="nj_login_name" select="//ef:profile/ef:login-name/."/>

  <!-- images and css directories locations -->
  <xsl:variable name="nj_img" select="concat('/', $_root_context, '/themes/nice-jump/images')"/>
  <xsl:variable name="nj_css" select="concat('/', $_root_context, '/themes/nice-jump/css')"/>
  <xsl:variable name="nj_js" select="concat('/', $_root_context, '/themes/nice-jump/js/layout.js', '?', $_ef_cache_timestamp)"/>
  <xsl:variable name="nj_fonts" select="concat('/', $_root_context, '/third-party/font/font-awesome')"/>

  <!-- admin portal uri -->
  <xsl:variable name="nj_admin_uri" select="concat('/', $_root_context, '/admin/com.enginframe.admin.xml')"/>
  <xsl:variable name="nj_interactive_settings_uri">?_uri=//com.enginframe.interactive/settings</xsl:variable>
  
  <xsl:variable name="nj_change_password_uri">?_service=change_ldap_password</xsl:variable>

  <!-- CSS parameters -->
  <xsl:template name="nj_css_params">
    <link rel="stylesheet" href="{$nj_fonts}/css/font-awesome.min.css?{$_ef_cache_timestamp}" />
  </xsl:template>

  <!-- default welcome service uri -->
  <xsl:variable name="nj.welcome.service">_service=welcome</xsl:variable>

  <!-- html header rendering -->
  <xsl:template name="nj_head_rendering">
    <title><xsl:value-of select="$nj.title"/></title>

    <link rel="shortcut icon" href="{$nj.favicon}" />

    <!-- System head -->
    <xsl:call-template name="head_rendering"/>

    <!-- include css stylesheets -->
    <link type="text/css" rel="StyleSheet" href="{$nj_css}/layout.css?{$_ef_cache_timestamp}" />
    <xsl:if test="($ef.browser.name='ie') and ($ef.browser.version&lt;'10.0')">
        <link type="text/css" rel="StyleSheet" href="{$nj_css}/layout.ie9.css?{$_ef_cache_timestamp}" />
    </xsl:if>

    <link type="text/css" rel="StyleSheet" href="{$nj_css}/logo.css?{$_ef_cache_timestamp}" />

    <!-- Custom head section hook -->
    <xsl:apply-templates select="/ef:agent" mode="layout.head"/>

    <!-- navigation hide/show animation -->
    <script type="text/javascript" src="{$nj_js}">
      <xsl:comment>//</xsl:comment>
    </script>

    <!-- Custom jquery ui -->
    <!-- <script type="text/javascript" src="{$nj_jqueryui_js}">
      <xsl:comment>//</xsl:comment>
    </script>
     -->

    <xsl:if test="not($_service) and not($_uri)">
      <script>
        jQuery(document).ready(function () {
          window.location.replace("<xsl:value-of select="encode:forJavaScriptBlock($agent)"/>.xml?<xsl:value-of select="encode:forJavaScriptBlock($nj.welcome.service)"/>");
        });
      </script>
    </xsl:if>

    <!-- CSS parameters -->
    <xsl:call-template name="nj_css_params"/>
  </xsl:template>

  <!-- banner rendering -->
  <xsl:template name="nj_banner_rendering">
    <xsl:apply-templates select="/ef:agent" mode="layout.banner"/>
  </xsl:template>

  <!-- contents rendering -->
  <xsl:template name="nj_content_rendering">
    <!-- main content -->
    <div id="nj-content-wrapper">
       <div id="nj-content-header">
         <span id="nj-content-title"/>
       </div>
       <div id="nj-content-div">
         <!-- System content -->
         <xsl:call-template name="content_rendering"/>
       </div>
    </div>
  </xsl:template>

  <!-- navigation rendering -->
  <xsl:template name="nj_navigation_rendering">
     <div id="nj-navigation-wrapper">
       <div id="nj-navigation-header">
         <span id="nj-navigation-title">
           <xsl:value-of select="$nj.navigation.title"/>
         </span>
         <span id="nj-navigation-close-button">
           <a class="toggle" href="#"><i class="fa fa-times"></i></a>
         </span>
         <span id="nj-navigation-open-button" class="ui-helper-hidden">
           <a class="toggle" href="#"><i class="fa fa-bars"></i></a>
         </span>
       </div>
       <div id="nj-navigation-div">
         <div class="ef-navigation ef-navigation-treeview ui-widget start-hidden">
           <ul>
             <xsl:call-template name="item_action_list_rendering"/>
             <xsl:call-template name="navigation_rendering"/>
           </ul>
         </div>
       </div>
     </div>
  </xsl:template>

  <!-- footer rendering -->
  <xsl:template name="nj_footer_rendering">
    <xsl:apply-templates select="/ef:agent" mode="layout.footer"/>
  </xsl:template>

  <xsl:template name="nj_footer_login_rendering">
    <xsl:apply-templates select="/ef:agent" mode="layout.login.footer"/>
  </xsl:template>

  <!-- Overridable templates -->

  <!-- head section hook -->
  <xsl:template match="/ef:agent" mode="layout.head" priority="-1" />

  <!-- banner content -->
  <xsl:template match="/ef:agent" mode="layout.banner" priority="-1">
    <div id="nj-banner">
       <a href="{$nj.logo.href}">
         <h1 id="nj-banner-logo">EnginFrame</h1>
       </a>
      <xsl:if test="$nj.headline">
        <h1 id="nj-banner-headline"><xsl:value-of select="$nj.headline"/></h1>
      </xsl:if>
      <div id="nj-banner-actions" >
        <xsl:choose>
          <xsl:when test="$nj_login_name != ''">
            <span class="nj-banner-nolink">
               <xsl:copy-of select="$nj.portal.icon"/>
               Welcome, <xsl:value-of select="$nj_login_name"/></span>
            <span>
                <a href="{$nj.change.password.uri}" title="{$nj.change.password.name}">
                  <xsl:value-of select="$nj.change.password.name"/>
                </a>
            </span>   
            <xsl:if test="$nj.show.interactive.settings.link='true'">
              <span>
                <a href="{$nj.interactive.settings.uri}" title="{$nj.interactive.settings.name}">
                  <xsl:value-of select="$nj.interactive.settings.name"/>
                </a>
              </span>
            </xsl:if>
            <xsl:if test="$nj.show.admin.link='true'">
              <!-- admin link-->
              <xsl:call-template name="nj_admin_link"/>
            </xsl:if>
            <span>
              <a id="nj-logout-link" href="{$nj.logout.uri}">Logout</a>
            </span>
            <script type="text/javascript">
              if (jQuery.cookie('EF_AUTH_COOKIE')) {
                jQuery('#nj-logout-link').hide();
              } else {
                jQuery('#nj-logout-link').show();
              }
            </script>
          </xsl:when>
          <xsl:otherwise>
            <xsl:if test="$nj.login.uri">
              <a href="{$nj.login.uri}">Login</a>
            </xsl:if>
          </xsl:otherwise>
        </xsl:choose>
      </div>
    </div>
  </xsl:template>

  <!-- footer -->
  <xsl:template match="/ef:agent" mode="layout.footer" priority="-1">
    <div id="nj-footer">
      <p>
        <a href="{$nj.footer.logo.href}">
            <img id="nj-footer-logo" src="{$nj.footer.logo}" />
        </a>
        <xsl:copy-of select="$nj.copyright"/>
        <xsl:copy-of select="$nj.credits"/>
      </p>
    </div>
  </xsl:template>

  <!-- login footer content -->
  <xsl:template match="/ef:agent" mode="layout.login.footer" priority="-1">
    <div id="nj-login-footer">
      <p>
        <a href="{$nj.footer.logo.href}">
            <img id="nj-footer-logo" src="{$nj.footer.logo}" />
        </a>
        <br />
        <xsl:copy-of select="$nj.login.copyright"/>
        <xsl:copy-of select="$nj.credits"/>
      </p>
    </div>
  </xsl:template>

  <xsl:template name="nj_admin_link" priority="-1">
    <efx:acl>
      <ef:apply-acl select="admin-only">
        <span>
          <a href="{$nj.ext.portal.uri}" title="{$nj.ext.portal.name}">
            <xsl:value-of select="$nj.ext.portal.name"/>
          </a>
        </span>
      </ef:apply-acl>
    </efx:acl>
  </xsl:template>

  <!-- com.enginframe.navigation override -->

  <xsl:template match="/ef:agent[$ef.navigation = 'treeview']" mode="navigation" priority="+2">
    <xsl:choose>
      <xsl:when test="descendant::ef:folder[@id=$ef.navigation.root]/*">
        <xsl:apply-templates select="descendant::ef:folder[@id=$ef.navigation.root]" mode="navigation"/>
      </xsl:when>
      <xsl:otherwise><i>- No services available -</i></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ef:folder[$ef-real-navigation = 'plain' and @id=$ef.navigation.root]" mode="navigation" priority="+2">
    <xsl:apply-templates select="ef:name" mode="navigation"/>
    <xsl:apply-templates select="ef:folder|ef:service|ef:spooler" mode="navigation"/>
    <xsl:text> </xsl:text>
  </xsl:template>

  <!-- Any service name -->
  <xsl:template match="ef:service[$ef-real-navigation = 'plain']/ef:name" mode="navigation" priority="+2">
    <a>
      <xsl:attribute name="href">
        <xsl:apply-templates select=".." mode="navigation-href"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="parent::ef:service/ef:metadata[@attribute='SM_SERVICE_TYPE'] = 'batch'">
          <i class="fa fa-cogs"></i>
        </xsl:when>
        <xsl:when test="parent::ef:service/ef:metadata[@attribute='SM_SERVICE_TYPE'] = 'interactive'">
          <xsl:choose>
            <xsl:when test="parent::ef:service/ef:metadata[@attribute='VDI_OS'] = 'windows'">
              <i class="fa fa-windows"></i>
            </xsl:when>
            <xsl:when test="parent::ef:service/ef:metadata[@attribute='VDI_OS'] = 'linux'">
              <i class="fa fa-linux"></i>
            </xsl:when>
          </xsl:choose>
        </xsl:when>
      </xsl:choose>
      <!-- ef:name/text() is already html-encoded -->
      <xsl:value-of select="text()"/>
    </a>
  </xsl:template>

  <!-- Top menu classes mapping -->

  <xsl:variable name="topmenuNavigationMap">
    <folder>
      <label>Data</label>
      <class>ef-data</class>
    </folder>
    <folder>
      <label>Monitor</label>
      <class>ef-monitor</class>
    </folder>
  </xsl:variable>
  <xsl:variable name="topmenuNavigationMapNS" select="exsl:node-set($topmenuNavigationMap)" />

  <xsl:template match="/folder" mode="nj-navigation">
    <xsl:param name="efItemActionList" />
      <li>
        <xsl:attribute name="class">
          <xsl:text>ef-navigation-folder </xsl:text>
          <xsl:apply-templates select="@class" mode="navigation"/>
        </xsl:attribute>
        <span class="ef-navigation-folder-name">
          <xsl:value-of select="label" />
        </span>
        <ul>
          <xsl:apply-templates select="class" mode="nj-navigation">
            <xsl:with-param name="efItemActionList" select="$efItemActionList"/>
          </xsl:apply-templates>
        </ul>
      </li>
  </xsl:template>

  <xsl:template match="/folder/class" mode="nj-navigation">
    <xsl:param name="efItemActionList" />
    <xsl:variable name="itsClass" select="text()" />
    <xsl:apply-templates select="$efItemActionList/descendant::ef:item-action[@class = $itsClass]" />
  </xsl:template>

  <!-- com.enginframe.menu override -->

  <xsl:template match="ef:item-action-list" priority="+2">
    <xsl:apply-templates select="$topmenuNavigationMapNS/folder" mode="nj-navigation">
      <xsl:with-param name="efItemActionList" select="."/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="ef:item-action" priority="+2">
    <xsl:apply-templates select="@id|@class"/>
    <li>
      <xsl:attribute name="class">
        <xsl:text>ef-navigation-item </xsl:text>
        <xsl:apply-templates select="@class" />
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="efactions:*">
          <xsl:apply-templates select="efactions:*"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="ef:name"/>
        </xsl:otherwise>
      </xsl:choose>
    </li>
  </xsl:template>

</xsl:stylesheet>
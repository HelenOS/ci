<!--
  - Copyright (c) 2017 Vojtech Horky
  - All rights reserved.
  -
  - Redistribution and use in source and binary forms, with or without
  - modification, are permitted provided that the following conditions
  - are met:
  -
  - - Redistributions of source code must retain the above copyright
  -   notice, this list of conditions and the following disclaimer.
  - - Redistributions in binary form must reproduce the above copyright
  -   notice, this list of conditions and the following disclaimer in the
  -   documentation and/or other materials provided with the distribution.
  - - The name of the author may not be used to endorse or promote products
  -   derived from this software without specific prior written permission.
  -
  - THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
  - IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
  - OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
  - IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
  - INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
  - NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  - DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  - THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  - (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
  - THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
  -->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml">

<xsl:output method="html" indent="yes" />

<xsl:param name="CONFIG_RESOURCE_DIR" select="''" />
<xsl:param name="CONFIG_RSS_PATH" select="''" />

<xsl:template name="HTML_PAGE">
    <xsl:param name="TITLE" />
    <xsl:param name="EXTRA_HEAD" select="''" />
    <xsl:param name="BODY" />
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <title><xsl:value-of select="$TITLE" /></title>
        <script type="text/javascript" src="{$CONFIG_RESOURCE_DIR}jquery-2.1.4.min.js"></script>
        <link rel="stylesheet" href="{$CONFIG_RESOURCE_DIR}main.css" type="text/css" />
        <xsl:if test="$CONFIG_RSS_PATH != ''">
            <link rel="alternate" href="{$CONFIG_RSS_PATH}" type="application/rss+xml" title="Last builds" />
        </xsl:if>
        <xsl:copy-of select="$EXTRA_HEAD" />
    </head>
    <body>
        <xsl:copy-of select="$BODY" />
    </body>
</html>
</xsl:template>


<xsl:template match="build" mode="html-summary-table">
    <table class="summary">
        <thead>
            <tr>
                <th width="*">Task</th>
                <th style="width:8em">Success</th>
                <th width="width:40em">Details (total = ok + failed + skipped)</th>
            </tr>
        </thead>
        <tbody>
            <xsl:call-template name="html-summary-table-row">
                <xsl:with-param name="task" select="'checkout'" />
                <xsl:with-param name="title" select="'Repository checkouts'" />
            </xsl:call-template>
            <xsl:call-template name="html-summary-table-row">
                <xsl:with-param name="task" select="'helenos-build'" />
                <xsl:with-param name="title" select="'HelenOS builds'" />
            </xsl:call-template>
            <xsl:call-template name="html-summary-table-row">
                <xsl:with-param name="task" select="'harbour-fetch'" />
                <xsl:with-param name="title" select="'Tarball fetches for Coastline'" />
            </xsl:call-template>
            <xsl:call-template name="html-summary-table-row">
                <xsl:with-param name="task" select="'harbour-build'" />
                <xsl:with-param name="title" select="'Coastline builds'" />
            </xsl:call-template>
            <xsl:call-template name="html-summary-table-row">
                <xsl:with-param name="task" select="'test'" />
                <xsl:with-param name="title" select="'Testing scenarios'" />
            </xsl:call-template>
        </tbody>
    </table>
</xsl:template>


<xsl:template name="html-summary-table-row">
<xsl:param name="task" />
<xsl:param name="title" />
<xsl:variable name="taskOk" select="count(*[name()=$task and @result='ok'])" />
<xsl:variable name="taskFail" select="count(*[name()=$task and @result='fail'])" />
<xsl:variable name="taskSkip" select="count(*[name()=$task and @result='skip'])" />
<xsl:variable name="taskAll" select="count(*[name()=$task])" />
<xsl:variable name="percents">
    <xsl:choose>
        <xsl:when test="$taskAll = 0">
            <xsl:text>-</xsl:text>
        </xsl:when>
        <xsl:otherwise>
            <xsl:value-of select="round(100 * $taskOk div $taskAll)" /><xsl:text> %</xsl:text>
        </xsl:otherwise>
    </xsl:choose>
</xsl:variable>
<xsl:variable name="trClass">
    <xsl:choose>
        <xsl:when test="$taskAll = 0">
            <xsl:text>results-none</xsl:text>
        </xsl:when>
        <xsl:otherwise>
            <xsl:text>results-</xsl:text>
            <xsl:value-of select="10 * floor(10 * $taskOk div $taskAll)" />
        </xsl:otherwise>
    </xsl:choose>
</xsl:variable>
<tr>
    <xsl:attribute name="class">
        <xsl:value-of select="$trClass" />
    </xsl:attribute>
    <td>
	    <xsl:value-of select="$title" />
    </td>
    <td>
	    <xsl:value-of select="$percents" />
    </td>
    <td>
        <xsl:value-of select="$taskAll" />
        <xsl:text> = </xsl:text>
        <xsl:value-of select="$taskOk" />
        <xsl:text> + </xsl:text>
        <xsl:value-of select="$taskFail" />
        <xsl:text> + </xsl:text>
        <xsl:value-of select="$taskSkip" />
    </td>
</tr>
</xsl:template>

</xsl:stylesheet>

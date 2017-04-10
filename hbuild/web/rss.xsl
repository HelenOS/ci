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

<xsl:import href="common.xsl" />

<xsl:param name="PREVIOUS_BUILDS" select="''" />
<xsl:param name="BASE_URL" select="'http://ci.helenos.org/'" />
<xsl:param name="RSS_TAG_PREFIX" select="'ci.helenos.org'" />

<xsl:param name="WEB_ROOT_ABSOLUTE_FILE_PATH" select="'/srv/www/'" />


<xsl:output method="xml" indent="yes" />

<xsl:template match="/" xmlns="http://www.w3.org/2005/Atom">
<feed version="2.0" xmlns:xhtml="http://www.w3.org/1999/xhtml">
    <title>HelenOS Continuous Integration Testing Results</title>
    <description></description>
    <link href="{$BASE_URL}" />
    
    <xsl:apply-templates select="build" />
    
    <xsl:if test="normalize-space($PREVIOUS_BUILDS) != ''">
        <xsl:call-template name="MAKE_PREVIOUS_BUILDS">
            <xsl:with-param name="BUILDS" select="normalize-space($PREVIOUS_BUILDS)" />
        </xsl:call-template>
    </xsl:if>
</feed>
</xsl:template>



<xsl:template name="MAKE_PREVIOUS_BUILDS" xmlns="http://www.w3.org/2005/Atom">
    <xsl:param name="BUILDS" />
    <xsl:variable name="FIRST">
        <xsl:choose>
            <xsl:when test="substring-before($BUILDS, ' ') = ''">
                <xsl:value-of select="$BUILDS" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="substring-before($BUILDS, ' ')" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:variable name="REMAINING" select="substring-after($BUILDS, ' ')" />
    
    <xsl:variable name="FILENAME">
        <xsl:value-of select="$WEB_ROOT_ABSOLUTE_FILE_PATH" />
        <xsl:text>/build-</xsl:text>
        <xsl:value-of select="$FIRST" />
        <xsl:text>/report.xml</xsl:text>
    </xsl:variable>
    
    <xsl:for-each select="document($FILENAME)">
        <xsl:apply-templates select="build" />
    </xsl:for-each>
    
    <xsl:if test="$REMAINING != ''" >
        <xsl:call-template name="MAKE_PREVIOUS_BUILDS">
            <xsl:with-param name="BUILDS" select="$REMAINING" />
        </xsl:call-template>
    </xsl:if>
</xsl:template>


<xsl:template match="build" xmlns="http://www.w3.org/2005/Atom">
<entry>
    <title>Build <xsl:value-of select="@number" /></title>
    <link>
        <xsl:attribute name="href">
            <xsl:value-of select="$BASE_URL" />
            <xsl:text>build-</xsl:text>
            <xsl:value-of select="@number" />
            <xsl:text>/</xsl:text>
        </xsl:attribute>
    </link>
    <updated><xsl:value-of select="@date" /></updated>
    <id>tag:<xsl:value-of select="$RSS_TAG_PREFIX" />,build-<xsl:value-of select="@number" /></id>
    <content type="xhtml">
    
    <xhtml:div xmlns:xhtml="http://www.w3.org/1999/xhtml">
    <xhtml:h1>HelenOS CI results for build <xsl:value-of select="@number" /></xhtml:h1>
        <xsl:apply-templates select="." mode="rss-summary-table" />
        
        <xsl:choose>
            <xsl:when test="count(*[@result='fail']) = 0">
                <xhtml:p>There were no failures.</xhtml:p>
            </xsl:when>
            <xsl:otherwise>
            <xhtml:h2>Overview of failed tasks</xhtml:h2>
        <xhtml:table border="1" cellspacing="0" cellpadding="2">
            <xhtml:tr>
                <xhtml:th>Action</xhtml:th>
                <xhtml:th>Component</xhtml:th>
                <xhtml:th>Architecture</xhtml:th>
                <xhtml:th>Reason</xhtml:th>
            </xhtml:tr>
            <xsl:apply-templates select="*[@result='fail']" mode="failed.summary.row.rss" />
        </xhtml:table>
            </xsl:otherwise>
        </xsl:choose>
        
    </xhtml:div>
    </content>
</entry>
</xsl:template>

<xsl:template match="build" mode="rss-summary-table" xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
    <xhtml:table border="1" cellspacing="0" cellpadding="2">
        <xhtml:thead>
            <xhtml:tr>
                <xhtml:th>Task</xhtml:th>
                <xhtml:th>Success</xhtml:th>
                <xhtml:th>Details (total = ok + failed + skipped)</xhtml:th>
            </xhtml:tr>
        </xhtml:thead>
        <xhtml:tbody>
            <xsl:call-template name="rss-summary-table-row">
                <xsl:with-param name="task" select="'checkout'" />
                <xsl:with-param name="title" select="'Repository checkouts'" />
            </xsl:call-template>
            <xsl:call-template name="rss-summary-table-row">
                <xsl:with-param name="task" select="'helenos-build'" />
                <xsl:with-param name="title" select="'HelenOS builds'" />
            </xsl:call-template>
            <xsl:call-template name="rss-summary-table-row">
                <xsl:with-param name="task" select="'harbour-fetch'" />
                <xsl:with-param name="title" select="'Tarball fetches for Coastline'" />
            </xsl:call-template>
            <xsl:call-template name="rss-summary-table-row">
                <xsl:with-param name="task" select="'harbour-build'" />
                <xsl:with-param name="title" select="'Coastline builds'" />
            </xsl:call-template>
            <xsl:call-template name="rss-summary-table-row">
                <xsl:with-param name="task" select="'helenos-extra-build'" />
                <xsl:with-param name="title" select="'Extra HelenOS builds'" />
            </xsl:call-template>
            <xsl:call-template name="rss-summary-table-row">
                <xsl:with-param name="task" select="'test'" />
                <xsl:with-param name="title" select="'Testing scenarios'" />
            </xsl:call-template>
        </xhtml:tbody>
    </xhtml:table>
</xsl:template>

<xsl:template name="rss-summary-table-row" xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
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
<xhtml:tr>
    <xhtml:td>
        <xsl:value-of select="$title" />
    </xhtml:td>
    <xhtml:td>
        <xsl:value-of select="$percents" />
    </xhtml:td>
    <xhtml:td>
        <xsl:value-of select="$taskAll" />
        <xsl:text> = </xsl:text>
        <xsl:value-of select="$taskOk" />
        <xsl:text> + </xsl:text>
        <xsl:value-of select="$taskFail" />
        <xsl:text> + </xsl:text>
        <xsl:value-of select="$taskSkip" />
    </xhtml:td>
</xhtml:tr>
</xsl:template>

<xsl:template match="*" mode="failed.summary.row.rss"
xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xhtml:tr>
    <xsl:apply-templates select="." mode="failed.summary.row.2.rss" />
    <xhtml:td>
        <xsl:for-each select="log/logline[position() &gt; (last() - 10)]">
            <xsl:value-of select="text()" />
            <xhtml:br />
        </xsl:for-each>
    </xhtml:td>
</xhtml:tr>
</xsl:template>

<xsl:template match="checkout" mode="failed.summary.row.2.rss"
xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xhtml:td>repository checkout</xhtml:td>
<xhtml:td><xsl:value-of select="@repository" /></xhtml:td>
<xhtml:td></xhtml:td>
</xsl:template>

<xsl:template match="harbour-check" mode="failed.summary.row.2.rss"
xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xhtml:td>harbour self-check</xhtml:td>
<xhtml:td></xhtml:td>
<xhtml:td></xhtml:td>
</xsl:template>

<xsl:template match="harbour-fetch" mode="failed.summary.row.2.rss"
xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xhtml:td>tarball fetch</xhtml:td>
<xhtml:td><xsl:value-of select="@package" /></xhtml:td>
<xhtml:td></xhtml:td>
</xsl:template>

<xsl:template match="helenos-build" mode="failed.summary.row.2.rss"
xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xhtml:td>build</xhtml:td>
<xhtml:td>HelenOS</xhtml:td>
<xhtml:td><xsl:value-of select="@arch" /></xhtml:td>
</xsl:template>

<xsl:template match="harbour-build" mode="failed.summary.row.2.rss"
xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xhtml:td>build</xhtml:td>
<xhtml:td><xsl:value-of select="@package" /></xhtml:td>
<xhtml:td><xsl:value-of select="@arch" /></xhtml:td>
</xsl:template>


<xsl:template match="helenos-extra-build" mode="failed.summary.row.2.rss"
xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xhtml:td>build extended image</xhtml:td>
<xhtml:td>HelenOS with <xsl:value-of select="@packages" /></xhtml:td>
<xhtml:td><xsl:value-of select="@arch" /></xhtml:td>
</xsl:template>

<xsl:template match="test" mode="failed.summary.row.2.rss"
xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xhtml:td>test in VM</xhtml:td>
<xhtml:td><xsl:value-of select="@scenario" /></xhtml:td>
<xhtml:td><xsl:value-of select="@arch" /></xhtml:td>
</xsl:template>

<xsl:template match="*" mode="failed.summary.row.2.rss"
xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xhtml:td><xsl:value-of select="name()" /></xhtml:td>
<xhtml:td>---</xhtml:td>
<xhtml:td>---</xhtml:td>
</xsl:template>



</xsl:stylesheet>

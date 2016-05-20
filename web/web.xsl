<!--
  - Copyright (c) 2016 Vojtech Horky
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
<xsl:stylesheet version="1.1"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml">

<xsl:output method="html" indent="yes" />

<xsl:param name="OUTPUT_DIRECTORY" select="'html/'" />
<xsl:param name="BASE_URL" select="'http://helenos.alisma.cz/ci'" />
<xsl:param name="RSS_TAG_PREFIX" select="'ci.helenos.alisma.cz'" />

<xsl:key name="by-arch" match="/builds/build/*" use="@arch" />
<xsl:key name="by-harbour" match="/builds/build/*" use="@package" />
<xsl:key name="by-scenario" match="/builds/build/*" use="@scenario" />

<xsl:variable name="LINK_TO_TOP">
<span class="back-to-top"><a href="#top-of-page">(back to top)</a></span>
</xsl:variable>


<xsl:template match="/builds">
    <xsl:call-template name="HTML_PAGE">
        <xsl:with-param name="FILENAME" select="'index.html'" />
        <xsl:with-param name="TITLE" select="'HelenOS Continuous Integration'" />
        <xsl:with-param name="BODY">
            <h1>HelenOS Continuous Integration</h1>
            <xsl:for-each select="build">
                <xsl:sort select="@date" order="descending" />
                <xsl:if test="position() = 1">
                    <h2>Last Build Summary</h2>
                    <p class="action buttonset">
                        <a>
                            <xsl:attribute name="href">
                                <xsl:apply-templates select="." mode="build-filename" />
                            </xsl:attribute>
                            <xsl:text>See details of this build.</xsl:text>
                        </a>
                    </p>
                    <xsl:apply-templates select="." mode="html-summary-table" />
                </xsl:if>
            </xsl:for-each>
            
            <xsl:if test="count(build) &gt; 1">
                <h2>Previous Builds</h2>
                <ul class="previous-builds buttonset">
                    <xsl:for-each select="build">
                        <xsl:sort select="@date" order="descending" />
                        <xsl:if test="position() &gt; 1">
                            <li>
                                <a>
                                    <xsl:attribute name="href">
                                        <xsl:apply-templates select="." mode="build-filename" />
                                    </xsl:attribute>
                                    <xsl:text>Build&#160;</xsl:text>
                                    <xsl:value-of select="@number" />
                                </a>
                            </li>
                        </xsl:if>
                    </xsl:for-each>
                </ul>
            </xsl:if>
        </xsl:with-param>
    </xsl:call-template>
    
    <xsl:apply-templates select="build" />
    
    <xsl:apply-templates select="." mode="rss" />
</xsl:template>

<xsl:template match="/builds" mode="rss"  xmlns="http://www.w3.org/2005/Atom">
<xsl:document href="{concat($OUTPUT_DIRECTORY,'/', 'ci.rss.xml')}" method="xml" indent="yes"
xmlns="http://www.w3.org/2005/Atom">
<feed version="2.0" xmlns:xhtml="http://www.w3.org/1999/xhtml">
    <title>HelenOS Continuous Integration Testing Results</title>
    <description></description>
    <link href="{$BASE_URL}" />
    
    <xsl:for-each select="build">
        <xsl:sort select="@date" order="descending" />
        <xsl:apply-templates select="." mode="rss" />
    </xsl:for-each>
</feed>
</xsl:document>
</xsl:template>



<xsl:template match="build">
    <xsl:variable name="BUILD" select="." />

    <xsl:call-template name="HTML_PAGE">
        <xsl:with-param name="FILENAME">
           <xsl:apply-templates select="." mode="build-filename" />
        </xsl:with-param>
        <xsl:with-param name="TITLE">
            <xsl:text>HelenOS CI (build </xsl:text>
            <xsl:value-of select="@number" />
            <xsl:text>)</xsl:text>
        </xsl:with-param>
        <xsl:with-param name="EXTRA_HEAD">
            <script type="text/javascript" language="JavaScript">
            $( document ).ready(function() {
                $(".logdump").hide();
            });
            function showHideLog(link, target) {
                target = $(link).parents("table").find("." + target)
                if (target.is(":hidden")) {
                    target.show();
                    $(link).text("Hide");
                } else {
                    target.hide();
                    $(link).text("View");
                }
                return false;
            }
            </script>
        </xsl:with-param>
        <xsl:with-param name="BODY">
            <div id="centeredd">
        
        <h1 id="top-of-page">HelenOS continuous integration testing (build <xsl:value-of select="@number" />)</h1>
        <div id="summary">
            <h2>Summary results</h2>
            <xsl:apply-templates select="." mode="html-summary-table" />
        </div>
        
        <div id="quick-links" class="buttonset">
        <h2>Quick links</h2>
        
        <div class="quick-link-group">
        <h3>Miscellaneous</h3>
        <ul>
            <li><a href="#failures">List of failed tasks</a></li>
            <xsl:if test="helenos-build">
                <li><a href="#helenos">HelenOS</a></li>
            </xsl:if>
        </ul>
        </div>
        
        <xsl:if test="count(*[@arch]) &gt; 0">
        <div class="quick-link-group">
        <h3>Architectures</h3>
        <ul>
            <xsl:for-each select="*[@arch and count(. | key('by-arch', @arch)[parent::build = $BUILD][1]) = 1]">
            <xsl:sort select="@arch" />
            <xsl:variable name="ARCH" select="@arch" />
            <li><a href="#arch-{$ARCH}"><xsl:value-of select="$ARCH" /></a></li>
        </xsl:for-each>
        </ul>
        </div>
        </xsl:if>
        
        <xsl:if test="count(*[@package]) &gt; 0">
        <div class="quick-link-group">
        <h3>Harbours</h3>
        <ul>
            <xsl:for-each select="*[@package and count(. | key('by-harbour', @package)[parent::build = $BUILD][1]) = 1]">
                <xsl:sort select="@package" />
                <xsl:variable name="PKG" select="@package" />
                <li><a href="#harbour-{$PKG}"><xsl:value-of select="$PKG" /></a></li>
            </xsl:for-each>
        </ul>
        </div>
        </xsl:if>
        
        <xsl:if test="count(*[@scenario]) &gt; 0">
        <div class="quick-link-group">
        <h3>Testing scenarios</h3>
        <ul>
            <xsl:for-each select="*[@scenario and count(. | key('by-scenario', @scenario)[parent::build = $BUILD][1]) = 1]">
                <xsl:sort select="@scenario" />
                <xsl:variable name="SCENARIO" select="@scenario" />
                <li><a href="#scenario-{$SCENARIO}"><xsl:value-of select="$SCENARIO" /></a></li>
            </xsl:for-each>
        </ul>
        </div>
        </xsl:if>
        
        </div>
        
        <h2>Miscellaneous</h2>
        <h3 id="failures">List of failed tasks <xsl:copy-of select="$LINK_TO_TOP" /></h3>
        <xsl:choose>
            <xsl:when test="count(*[@result='fail']) = 0">
                <p>There were no failures.</p>
            </xsl:when>
            <xsl:otherwise>
                <table>
                    <thead>
                        <tr>
                            <th>Task</th>
                            <th>Component</th>
                            <th>Architecture</th>
                            <th>Log</th>
                        </tr>
                    </thead>
                    <tbody>
                        <xsl:for-each select="checkout[@result='fail']">
                            <xsl:sort select="@repository" />
                            <xsl:apply-templates select="." mode="html-failed-task-table-row" />
                        </xsl:for-each>
                        <xsl:apply-templates select="harbour-check[@result='fail']" mode="html-failed-task-table-row" />
                        <xsl:for-each select="helenos-build[@result='fail']">
                            <xsl:sort select="@arch" />
                            <xsl:apply-templates select="." mode="html-failed-task-table-row" />
                        </xsl:for-each>
                        <xsl:for-each select="harbour-fetch[@result='fail']">
                            <xsl:sort select="@package" />
                            <xsl:apply-templates select="." mode="html-failed-task-table-row" />
                        </xsl:for-each>
                        <xsl:for-each select="harbour-build[@result='fail']">
                            <xsl:sort select="@package" />
                            <xsl:sort select="@arch" />
                            <xsl:apply-templates select="." mode="html-failed-task-table-row" />
                        </xsl:for-each>
                        <xsl:for-each select="helenos-extra-build[@result='fail']">
                            <xsl:sort select="@arch" />
                            <xsl:sort select="@packages" />
                            <xsl:apply-templates select="." mode="html-failed-task-table-row" />
                        </xsl:for-each>
                        <xsl:for-each select="test[@result='fail']">
                            <xsl:sort select="@scenario" />
                            <xsl:sort select="@arch" />
                            <xsl:apply-templates select="." mode="html-failed-task-table-row" />
                        </xsl:for-each>
                        <!-- xsl:apply-templates select="*[@result='fail']" mode="html-failed-task-table-row" /-->
                    </tbody>
                </table>
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:if test="helenos-build">
        <h3 id="helenos">HelenOS <xsl:copy-of select="$LINK_TO_TOP" /></h3>
        <table>
            <thead>
                <tr>
                    <th>Architecture</th>
                    <th>Result</th>
                    <th>Log</th>
                </tr>
            </thead>
            <tbody>
                <xsl:for-each select="helenos-build">
                    <xsl:sort select="@arch" />
                    <tr class="result-{@result}">
                        <td>
                            <xsl:value-of select="@arch" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="yes-no" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                    </tr>
                    <xsl:apply-templates select="." mode="log-dump" />
                </xsl:for-each>
            </tbody>
        </table>
        </xsl:if>
           
        
        <xsl:if test="count(*[@arch]) &gt; 0">
        <h2>Per-architecture details <xsl:copy-of select="$LINK_TO_TOP" /></h2>
        <xsl:for-each select="$BUILD/*[@arch and count(. | key('by-arch', @arch)[parent::build = $BUILD][1]) = 1]">
            <xsl:sort select="@arch" />
            <xsl:variable name="ARCH" select="@arch" />
            <h3 id="arch-{$ARCH}"><xsl:value-of select="$ARCH" /><xsl:copy-of select="$LINK_TO_TOP" /></h3>
            <table>
                <thead>
                <tr>
                    <th>Task</th>
                    <th>Result</th>
                    <th>Log</th>
                </tr>
                </thead>
                <tbody>
                <tr class="result-{$BUILD/helenos-build[@arch=$ARCH]/@result}">
                    <td>HelenOS</td>
                    <td>
                        <xsl:apply-templates select="$BUILD/helenos-build[@arch=$ARCH]" mode="yes-no" />
                    </td>
                    <td>
                        <xsl:apply-templates select="$BUILD/helenos-build[@arch=$ARCH]" mode="log-link" />
                    </td>
                </tr>
                <xsl:apply-templates select="$BUILD/helenos-build[@arch=$ARCH]" mode="log-dump" />
                <xsl:for-each select="$BUILD/harbour-build[@arch=$ARCH]">
                    <tr class="result-{@result}">
                        <td><xsl:value-of select="@package" /></td>
                        <td>
                            <xsl:apply-templates select="." mode="yes-no" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                    </tr>
                    <xsl:apply-templates select="." mode="log-dump" />
                </xsl:for-each>
                <xsl:for-each select="$BUILD/helenos-extra-build[@arch=$ARCH]">
                    <tr class="result-{@result}">
                        <td>HelenOS and <xsl:value-of select="@packages" /></td>
                        <td>
                            <xsl:apply-templates select="." mode="yes-no" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                    </tr>
                    <xsl:apply-templates select="." mode="log-dump" />
                </xsl:for-each>
                <xsl:for-each select="$BUILD/test[@arch=$ARCH]">
                    <tr class="result-{@result}">
                        <td><xsl:value-of select="@scenario" /></td>
                        <td>
                            <xsl:apply-templates select="." mode="yes-no" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                        <xsl:apply-templates select="." mode="log-dump" />
                    </tr>
                </xsl:for-each>
                </tbody>
            </table>
        </xsl:for-each>
        </xsl:if>
        
        <xsl:if test="count(*[@package]) &gt; 0">
        <h2>Per-harbour details<xsl:copy-of select="$LINK_TO_TOP" /></h2>
        <xsl:for-each select="$BUILD/*[@package and count(. | key('by-harbour', @package)[parent::build = $BUILD][1]) = 1]">
            <xsl:sort select="@package" />
            <xsl:variable name="PKG" select="@package" />
            <h3 id="harbour-{$PKG}"><xsl:value-of select="$PKG" /><xsl:copy-of select="$LINK_TO_TOP" /></h3>
            <table>
                <thead>
                <tr>
                    <th>Architecture</th>
                    <th>Result</th>
                    <th>Log</th>
                </tr>
                </thead>
                <tbody>
                <tr class="result-{$BUILD/harbour-fetch[@package=$PKG]/@result}">
                    <td><i>Tarball fetch</i></td>
                    <td>
                        <xsl:apply-templates select="$BUILD/harbour-fetch[@package=$PKG]" mode="yes-no" />
                    </td>
                    <td>
                        <xsl:apply-templates select="$BUILD/harbour-fetch[@package=$PKG]" mode="log-link" />
                    </td>
                </tr>
                <xsl:apply-templates select="$BUILD/harbour-fetch[@package=$PKG]" mode="log-dump" />
                <xsl:for-each select="$BUILD/harbour-build[@package=$PKG]">
                    <xsl:sort select="@arch" />
                    <tr class="result-{@result}">
                        <td><xsl:value-of select="@arch" /></td>
                        <td>
                            <xsl:apply-templates select="." mode="yes-no" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                    </tr>
                    <xsl:apply-templates select="." mode="log-dump" />
                </xsl:for-each>
                </tbody>
            </table>
        </xsl:for-each>
        </xsl:if>
        
        <xsl:if test="count(*[@scenario]) &gt; 0">
        <h2>Per-scenario details<xsl:copy-of select="$LINK_TO_TOP" /></h2>
        <xsl:for-each select="$BUILD/*[@scenario and count(. | key('by-scenario', @scenario)[parent::build = $BUILD][1]) = 1]">
            <xsl:sort select="@scenario" />
            <xsl:variable name="SCENARIO" select="@scenario" />
            <h3 id="scenario-{$SCENARIO}"><xsl:value-of select="$SCENARIO" /><xsl:copy-of select="$LINK_TO_TOP" /></h3>
            <table>
                <thead>
                <tr>
                    <th>Architecture</th>
                    <th>Result</th>
                    <th>Log</th>
                </tr>
                </thead>
                <tbody>
                <xsl:for-each select="$BUILD/test[@scenario=$SCENARIO]">
                    <xsl:sort select="@arch" />
                    <tr class="result-{@result}">
                        <td><xsl:value-of select="@arch" /></td>
                        <td>
                            <xsl:apply-templates select="." mode="yes-no" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                    </tr>
                    <xsl:apply-templates select="." mode="log-dump" />
                </xsl:for-each>
                </tbody>
            </table>
        </xsl:for-each>
        </xsl:if>
        
        </div>
        </xsl:with-param>
    </xsl:call-template>
</xsl:template>


<xsl:template match="build" mode="rss" xmlns="http://www.w3.org/2005/Atom">
<entry>
    <title>Build <xsl:value-of select="@number" /></title>
    <link>
        <xsl:attribute name="href">
            <xsl:value-of select="$BASE_URL" />
            <xsl:text>/</xsl:text>
             <xsl:apply-templates select="." mode="build-filename" />
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



<xsl:template match="build" mode="build-filename">
    <xsl:text>b-</xsl:text>
    <xsl:value-of select="@number" />
    <xsl:text>.html</xsl:text>
</xsl:template>


<xsl:template name="HTML_PAGE">
    <xsl:param name="FILENAME" />
    <xsl:param name="TITLE" />
    <xsl:param name="EXTRA_HEAD" select="''" />
    <xsl:param name="BODY" />
<xsl:document
        href="{concat($OUTPUT_DIRECTORY,'/', $FILENAME)}"
        method="html"
        indent="yes"
>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <title><xsl:value-of select="$TITLE" /></title>
        <script type="text/javascript" src="jquery-2.1.4.min.js"></script>
        <link rel="stylesheet" href="main.css" type="text/css" />
        <link rel="alternate" href="ci.rss.xml" type="application/rss+xml" title="Last builds" />
        <xsl:copy-of select="$EXTRA_HEAD" />
    </head>
    <body>
        <xsl:copy-of select="$BODY" />
    </body>
</html>
</xsl:document>
</xsl:template>



<xsl:template match="*" mode="yes-no">
    <xsl:choose>
        <xsl:when test="@result = 'ok'">
            <xsl:text>OK</xsl:text>
        </xsl:when>
        <xsl:when test="@result = 'fail'">
            <xsl:text>Failed</xsl:text>
        </xsl:when>
        <xsl:when test="@result = 'skip'">
            <xsl:text>Skipped</xsl:text>
        </xsl:when>
        <xsl:otherwise>
            <xsl:text>? </xsl:text>
            <code>(<xsl:value-of select="@result" />)</code>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template match="*" mode="image-link">
    <xsl:if test="@image">
        <a href="{@image}">Image</a>
    </xsl:if>
</xsl:template>

<xsl:template match="*" mode="log-link">
    <xsl:choose>
        <xsl:when test="count(log/logline) > 0">
            <a href="#" onclick="return showHideLog(this, 'log-{generate-id(.)}');">View</a>
        </xsl:when>
        <xsl:otherwise>
            <xsl:text>--</xsl:text>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template match="*" mode="log-dump">
<xsl:if test="count(log/logline) > 0">
	<tr class="logdump log-{generate-id(.)}">
	    <td colspan="3">
<pre><xsl:for-each select="log/logline">
<xsl:value-of select="text()" /><xsl:text>
</xsl:text>
</xsl:for-each></pre>
	    </td>
	</tr>
</xsl:if>
</xsl:template>

<xsl:template match="*" mode="log-dump-4">
<xsl:if test="count(log/logline) > 0">
<tr class="logdump log-{generate-id(.)}">
    <td colspan="4">
<pre><xsl:for-each select="log/logline">
<xsl:value-of select="text()" /><xsl:text>
</xsl:text>
</xsl:for-each></pre>
    </td>
</tr>
</xsl:if>
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
                <xsl:with-param name="task" select="'helenos-extra-build'" />
                <xsl:with-param name="title" select="'Extra HelenOS builds'" />
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



<xsl:template match="*" mode="html-failed-task-table-row">
<tr class="result-fail">
    <xsl:apply-templates select="." mode="html-failed-task-table-row-inner" />
    <td>
        <xsl:apply-templates select="." mode="log-link" />
    </td>
</tr>
<xsl:apply-templates select="." mode="log-dump-4" />
</xsl:template>

<xsl:template match="checkout" mode="html-failed-task-table-row-inner">
    <td>Repository checkout</td>
    <td><xsl:value-of select="@repository" /></td>
    <td>&#8212;</td>
</xsl:template>

<xsl:template match="harbour-check" mode="html-failed-task-table-row-inner">
    <td>Harbour self-check</td>
    <td>&#8212;</td>
    <td>&#8212;</td>
</xsl:template>

<xsl:template match="harbour-fetch" mode="html-failed-task-table-row-inner">
    <td>Tarball fetch</td>
    <td><xsl:value-of select="@package" /></td>
    <td>&#8212;</td>
</xsl:template>

<xsl:template match="helenos-build" mode="html-failed-task-table-row-inner">
    <td>HelenOS</td>
    <td>&#8212;</td>
    <td><xsl:value-of select="@arch" /></td>
</xsl:template>

<xsl:template match="harbour-build" mode="html-failed-task-table-row-inner">
    <td>Harbour build</td>
    <td><xsl:value-of select="@package" /></td>
    <td><xsl:value-of select="@arch" /></td>
</xsl:template>

<xsl:template match="helenos-extra-build" mode="html-failed-task-table-row-inner">
    <td>Extras build</td>
    <td>HelenOS and <xsl:value-of select="@packages" /></td>
    <td><xsl:value-of select="@arch" /></td>
</xsl:template>

<xsl:template match="test" mode="html-failed-task-table-row-inner">
    <td>Test in VM</td>
    <td><xsl:value-of select="@scenario" /></td>
    <td><xsl:value-of select="@arch" /></td>
</xsl:template>

<xsl:template match="*" mode="html-failed-task-table-row-inner">
    <td><xsl:value-of select="name()" /></td>
    <td>&#8212;</td>
    <td>&#8212;</td>
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

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

<xsl:output
    method="xml"
    indent="yes"
    omit-xml-declaration="yes"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
    doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
/>

<xsl:key name="by-arch" match="/build/*" use="@arch" />
<xsl:key name="by-harbour" match="/build/*" use="@package" />
<xsl:key name="by-scenario" match="/build/*" use="@scenario" />

<xsl:variable name="LINK_TO_TOP">
<span class="back-to-top"><a href="#top-of-page">(back to top)</a></span>
</xsl:variable>


<xsl:template match="build">
    <xsl:variable name="BUILD" select="." />
    <xsl:call-template name="HTML_PAGE">
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
                    $(link).text("hide");
                } else {
                    target.hide();
                    $(link).text("tail");
                }
                return false;
            }
            </script>
        </xsl:with-param>
        <xsl:with-param name="BODY">
            <div id="centeredd">
        
        <h1 id="top-of-page">HelenOS continuous integration testing</h1>
        <h2 id="build-info">
            Build <xsl:value-of select="@number" /> from <xsl:value-of select="buildinfo/@started" />
            (<xsl:apply-templates select="buildinfo" mode="duration" />)
        </h2>
        <div id="summary">
            <h2>Summary results</h2>
            <xsl:apply-templates select="." mode="html-summary-table" />
        </div>
        
        <div id="quick-links" class="buttonset">
        <h2>Quick links</h2>
        
        <div class="quick-link-group">
        <h3>Miscellaneous</h3>
        <ul>
        	<li><a href="#matrix">Summary matrix</a></li>
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
        
        <h2 id="matrix">Summary matrix<xsl:copy-of select="$LINK_TO_TOP" /></h2>
        <table class="matrix">
            <thead>
            <tr>
                <th></th>
                <xsl:for-each select="*[@arch and count(. | key('by-arch', @arch)[parent::build = $BUILD][1]) = 1]">
                    <xsl:sort select="@arch" />
                    <th>
                        <a href="#arch-{@arch}">
                            <xsl:apply-templates select="@arch" mode="architecture-with-hyphens" />
                        </a>
                    </th>
                </xsl:for-each>
            </tr>
            </thead>
            <tbody>
                <tr>
                    <th>
                        <a href="#helenos">HelenOS</a>
                    </th>
                    <xsl:for-each select="*[@arch and count(. | key('by-arch', @arch)[parent::build = $BUILD][1]) = 1]">
	                    <xsl:sort select="@arch" />
	                    <xsl:variable name="ARCH" select="@arch" />
	                    <xsl:variable name="RESULT" select="//helenos-build[@arch=$ARCH]" />
	                    <td class="result-{$RESULT/@result}"><xsl:apply-templates select="$RESULT" mode="log-link-matrix" /></td>
                    </xsl:for-each>
                </tr>
                <xsl:for-each select="*[@package and count(. | key('by-harbour', @package)[parent::build = $BUILD][1]) = 1]">
                    <xsl:sort select="@package" />
                    <xsl:variable name="PKG" select="@package" />
                    <tr>
                        <th>
                            <a href="#harbour-{$PKG}">
                                <xsl:value-of select="$PKG" />
                            </a>
                        </th>
                        <xsl:for-each select="//*[@arch and count(. | key('by-arch', @arch)[parent::build = $BUILD][1]) = 1]">
                            <xsl:sort select="@arch" />
                            <xsl:variable name="ARCH" select="@arch" />
                            <xsl:variable name="RESULT" select="//harbour-build[@arch=$ARCH and @package=$PKG]" />
                            <xsl:choose>
                                <xsl:when test="$RESULT">
                                    <td class="result-{$RESULT/@result}"><xsl:apply-templates select="$RESULT" mode="log-link-matrix" /></td>
                                </xsl:when>
                                <xsl:otherwise>
                                    <td class="result-na">N/A</td>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>
                    </tr>
                </xsl:for-each>
                <xsl:for-each select="*[@scenario and count(. | key('by-scenario', @scenario)[parent::build = $BUILD][1]) = 1]">
                    <xsl:sort select="@scenario" />
                    <xsl:variable name="SCENARIO" select="@scenario" />
                    <tr>
                        <th style="white-space: nowrap;">
                            <a title="{$SCENARIO}" href="#scenario-{$SCENARIO}">
                                <xsl:value-of select="$SCENARIO" />
                            </a>
                        </th>
                        <xsl:for-each select="//*[@arch and count(. | key('by-arch', @arch)[parent::build = $BUILD][1]) = 1]">
                            <xsl:sort select="@arch" />
                            <xsl:variable name="ARCH" select="@arch" />
                            <xsl:variable name="RESULT" select="//test[@arch=$ARCH and @scenario=$SCENARIO]" />
                            <xsl:choose>
                                <xsl:when test="$RESULT">
                                    <td class="result-{$RESULT/@result}"><xsl:apply-templates select="$RESULT" mode="log-link-matrix" /></td>
                                </xsl:when>
                                <xsl:otherwise>
                                    <td class="result-na">N/A</td>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>
                    </tr>
                </xsl:for-each>
            </tbody>
        </table>
        
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
                            <th width="25%">Task</th>
                            <th width="25%">Component</th>
                            <th width="20%">Architecture</th>
                            <th width="20%">Log</th>
                            <th width="10%">Duration</th>
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
                    <th width="25%">Architecture</th>
                    <th width="10%">Result</th>
                    <th width="35%">Download</th>
                    <th width="20%">Log</th>
                    <th width="10%">Duration</th>
                </tr>
            </thead>
            <tbody>
                <xsl:if test="browsable-sources-global">
                    <tr class="result-{browsable-sources-global/@result}">
                        <td>
                            <xsl:text disable-output-escaping="yes"><![CDATA[&mdash;]]></xsl:text>
                        </td>
                        <td>
                            <xsl:apply-templates select="browsable-sources-global" mode="yes-no" />
                        </td>
                        <td>
                            <xsl:apply-templates select="browsable-sources-global" mode="download" />
                        </td>
                        <td>
                            <xsl:apply-templates select="browsable-sources-global" mode="log-link" />
                        </td>
                        <td>
                            <xsl:apply-templates select="browsable-sources-global" mode="duration" />
                        </td>
                    </tr>
                </xsl:if>
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
                            <xsl:apply-templates select="." mode="download" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="duration" />
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
                    <th width="25%">Task</th>
                    <th width="10%">Result</th>
                    <th width="35%">Download</th>
                    <th width="20%">Log</th>
                    <th width="10%">Duration</th>
                </tr>
                </thead>
                <tbody>
                <tr class="result-{$BUILD/helenos-build[@arch=$ARCH]/@result}">
                    <td>HelenOS</td>
                    <td>
                        <xsl:apply-templates select="$BUILD/helenos-build[@arch=$ARCH]" mode="yes-no" />
                    </td>
                    <td>
                        <xsl:apply-templates select="." mode="download" />
                    </td>
                    <td>
                        <xsl:apply-templates select="$BUILD/helenos-build[@arch=$ARCH]" mode="log-link" />
                    </td>
                    <td>
                        <xsl:apply-templates select="." mode="duration" />
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
                            <xsl:apply-templates select="." mode="download" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="duration" />
                        </td>
                    </tr>
                    <xsl:apply-templates select="." mode="log-dump" />
                </xsl:for-each>
                <xsl:for-each select="$BUILD/helenos-extra-build[@arch=$ARCH]">
                    <tr class="result-{@result}">
                        <td>HelenOS with <xsl:value-of select="@harbours" /></td>
                        <td>
                            <xsl:apply-templates select="." mode="yes-no" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="download" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="duration" />
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
                            <xsl:apply-templates select="." mode="download" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="duration" />
                        </td>
                    </tr>
                    <xsl:apply-templates select="." mode="log-dump" />
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
                    <th width="25%">Architecture</th>
                    <th width="10%">Result</th>
                    <th width="35%">Download</th>
                    <th width="20%">Log</th>
                    <th width="10%">Duration</th>
                </tr>
                </thead>
                <tbody>
                <tr class="result-{$BUILD/harbour-fetch[@package=$PKG]/@result}">
                    <td><i>Tarball fetch</i></td>
                    <td>
                        <xsl:apply-templates select="$BUILD/harbour-fetch[@package=$PKG]" mode="yes-no" />
                    </td>
                    <td>
                        <xsl:apply-templates select="." mode="download" />
                    </td>
                    <td>
                        <xsl:apply-templates select="$BUILD/harbour-fetch[@package=$PKG]" mode="log-link" />
                    </td>
                    <td>
                        <xsl:apply-templates select="." mode="duration" />
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
                            <xsl:apply-templates select="." mode="download" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="duration" />
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
                    <th width="25%">Architecture</th>
                    <th width="10%">Result</th>
                    <th width="35%">Download</th>
                    <th width="20%">Log</th>
                    <th width="10%">Duration</th>
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
                            <xsl:apply-templates select="." mode="download" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="log-link" />
                        </td>
                        <td>
                            <xsl:apply-templates select="." mode="duration" />
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

<xsl:template match="@*" mode="architecture-with-hyphens">
<xsl:variable name="PLATFORM" select="substring-before(., '/')" />
<xsl:variable name="MACHINE" select="substring-after(., '/')" />
    <xsl:choose>
        <xsl:when test="concat($PLATFORM, $MACHINE) = ''">
            <xsl:value-of select="." />
        </xsl:when>
        <xsl:otherwise>
            <xsl:value-of select="$PLATFORM" />
            <xsl:text> </xsl:text>
            <xsl:choose>
                <xsl:when test="$MACHINE = 'beagleboardxm'">
                    <xsl:text disable-output-escaping="yes"><![CDATA[beagle&shy;board&shy;xm]]></xsl:text>
                </xsl:when>
                <xsl:when test="$MACHINE = 'beaglebone'">
                    <xsl:text disable-output-escaping="yes"><![CDATA[beagle&shy;bone]]></xsl:text>
                </xsl:when>
                <xsl:when test="$MACHINE = 'malta-be'">
                    <xsl:text disable-output-escaping="yes"><![CDATA[malta&shy;-be]]></xsl:text>
                </xsl:when>
                <xsl:when test="$MACHINE = 'malta-le'">
                    <xsl:text disable-output-escaping="yes"><![CDATA[malta&shy;-le]]></xsl:text>
                </xsl:when>
                <xsl:when test="$MACHINE = 'integratorcp'">
                    <xsl:text disable-output-escaping="yes"><![CDATA[inte&shy;gra&shy;torcp]]></xsl:text>
                </xsl:when>
                <xsl:when test="$MACHINE = 'raspberrypi'">
                    <xsl:text disable-output-escaping="yes"><![CDATA[rasp&shy;ber&shy;ry&shy;pi]]></xsl:text>
                </xsl:when>
                <xsl:when test="$MACHINE = 'raspberrypi'">
                    <xsl:text disable-output-escaping="yes"><![CDATA[rasp&shy;ber&shy;ry&shy;pi]]></xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$MACHINE" />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:otherwise>
    </xsl:choose>
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
    <xsl:if test="@log">
        <a href="{@log}">View</a>
        <xsl:if test="log/logline">
          (<a href="#" onclick="return showHideLog(this, 'log-{generate-id(.)}');">tail</a>)
        </xsl:if>
    </xsl:if>
</xsl:template>

<xsl:template match="*" mode="log-link-matrix">
    <xsl:if test="@log">
        <a href="{@log}"><xsl:apply-templates select="." mode="yes-no" /></a>
    </xsl:if>
</xsl:template>

<xsl:template match="*" mode="duration">
    <xsl:if test="@duration">
        <xsl:variable name="SECONDS" select="@duration div 1000" />
        <xsl:variable name="MINUTES" select="floor($SECONDS div 60)" />
        <xsl:variable name="HOURS" select="floor($MINUTES div 60)" />
        <xsl:choose>
            <xsl:when test="$MINUTES &gt; 90">
                <xsl:value-of select="$HOURS" /><xsl:text disable-output-escaping="yes"><![CDATA[&#8201;]]>h </xsl:text>
                <xsl:value-of select="format-number($MINUTES - 60 * $HOURS, '#')" /><xsl:text disable-output-escaping="yes"><![CDATA[&#8201;]]>min</xsl:text>
            </xsl:when>
            <xsl:when test="$SECONDS &gt; 90">
                <xsl:value-of select="$MINUTES" /><xsl:text disable-output-escaping="yes"><![CDATA[&#8201;]]>min </xsl:text>
                <xsl:value-of select="format-number($SECONDS - 60 * $MINUTES, '#')" /><xsl:text disable-output-escaping="yes"><![CDATA[&#8201;]]>s</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="format-number($SECONDS, '#')" /><xsl:text disable-output-escaping="yes"><![CDATA[&#8201;]]>s</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <!-- (<xsl:value-of select="format-number(@duration div 1000, '#.00')" />s) -->
    </xsl:if>
</xsl:template>

<xsl:template match="*" mode="log-dump">
<xsl:if test="count(log/logline) > 0">
<tr class="logdump log-{generate-id(.)}">
    <td colspan="5">
<pre><xsl:for-each select="log/logline">
<xsl:value-of select="text()" /><xsl:text>
</xsl:text>
</xsl:for-each></pre>
    </td>
</tr>
</xsl:if>
</xsl:template>

<xsl:template match="*" mode="download">
    <xsl:for-each select="file">
        <a href="{@filename}"><xsl:value-of select="@title" /></a>
        <xsl:if test="not(last())">, </xsl:if>
    </xsl:for-each>
    <xsl:if test="not(file)">
        <xsl:text disable-output-escaping="yes"><![CDATA[&mdash;]]></xsl:text>
    </xsl:if>
</xsl:template>



<xsl:template match="*" mode="html-failed-task-table-row">
<tr class="result-fail">
    <xsl:apply-templates select="." mode="html-failed-task-table-row-inner" />
    <td>
        <xsl:apply-templates select="." mode="log-link" />
    </td>
    <td>
        <xsl:apply-templates select="." mode="duration" />
    </td>
</tr>
<xsl:apply-templates select="." mode="log-dump" />
</xsl:template>

<xsl:template match="checkout" mode="html-failed-task-table-row-inner">
    <td>Repository checkout</td>
    <td><xsl:value-of select="@repository" /></td>
    <td><xsl:text disable-output-escaping="yes"><![CDATA[&mdash;]]></xsl:text></td>
</xsl:template>

<xsl:template match="harbour-check" mode="html-failed-task-table-row-inner">
    <td>Harbour self-check</td>
    <td><xsl:text disable-output-escaping="yes"><![CDATA[&mdash;]]></xsl:text></td>
    <td><xsl:text disable-output-escaping="yes"><![CDATA[&mdash;]]></xsl:text></td>
</xsl:template>

<xsl:template match="harbour-fetch" mode="html-failed-task-table-row-inner">
    <td>Tarball fetch</td>
    <td><xsl:value-of select="@package" /></td>
    <td><xsl:text disable-output-escaping="yes"><![CDATA[&mdash;]]></xsl:text></td>
</xsl:template>

<xsl:template match="helenos-build" mode="html-failed-task-table-row-inner">
    <td>HelenOS</td>
    <td><xsl:text disable-output-escaping="yes"><![CDATA[&mdash;]]></xsl:text></td>
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
    <td><xsl:text disable-output-escaping="yes"><![CDATA[&mdash;]]></xsl:text></td>
    <td><xsl:text disable-output-escaping="yes"><![CDATA[&mdash;]]></xsl:text></td>
</xsl:template>

</xsl:stylesheet>

<!--
  - Copyright (c) 2018 Vojtech Horky
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
    xmlns="http://www.w3.org/2005/Atom"
    xmlns:xhtml="http://www.w3.org/1999/xhtml">

<xsl:import href="common.xsl" />

<xsl:param name="BASE_URL" select="'http://ci.helenos.org/'" />
<xsl:param name="RSS_TAG_PREFIX" select="'ci.helenos.org'" />
<xsl:param name="PREVIOUS_REPORTS" select="''" />


<xsl:variable name="PREVIOUS_REPORT">
    <xsl:choose>
        <xsl:when test="substring-before(normalize-space($PREVIOUS_REPORTS), ' ') = ''">
            <xsl:value-of select="normalize-space($PREVIOUS_REPORTS)" />
        </xsl:when>
        <xsl:otherwise>
            <xsl:value-of select="substring-before(normalize-space($PREVIOUS_REPORTS), ' ')" />
        </xsl:otherwise>
    </xsl:choose>
</xsl:variable>


<xsl:output method="xml" indent="yes" />


<xsl:template match="/" xmlns="http://www.w3.org/2005/Atom">
    <feed version="2.0" xmlns:xhtml="http://www.w3.org/1999/xhtml">
        <title>HelenOS nightly builds difference results</title>
        <description></description>
        <link href="{$BASE_URL}" />

        <xsl:if test="normalize-space($PREVIOUS_REPORTS) != ''">
            <xsl:call-template name="SHOW_DIFF">
                <xsl:with-param name="FIRST" select="/" />
                <xsl:with-param name="SECOND" select="document($PREVIOUS_REPORT)" />
            </xsl:call-template>
            <xsl:call-template name="MAKE_DIFFS">
                <xsl:with-param name="BUILDS" select="normalize-space($PREVIOUS_REPORTS)" />
            </xsl:call-template>
        </xsl:if>
    </feed>
</xsl:template>


<xsl:template name="MAKE_DIFFS">
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

    <xsl:if test="$REMAINING != ''" >
           <xsl:variable name="SECOND">
            <xsl:choose>
                <xsl:when test="substring-before($REMAINING, ' ') = ''">
                    <xsl:value-of select="$REMAINING" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="substring-before($REMAINING, ' ')" />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:call-template name="SHOW_DIFF">
            <xsl:with-param name="FIRST" select="document($FIRST)" />
            <xsl:with-param name="SECOND" select="document($SECOND)" />
        </xsl:call-template>
        <xsl:call-template name="MAKE_DIFFS">
            <xsl:with-param name="BUILDS" select="$REMAINING" />
        </xsl:call-template>
    </xsl:if>
</xsl:template>

<xsl:template name="SHOW_DIFF" xmlns="http://www.w3.org/2005/Atom">
    <xsl:param name="FIRST" />
    <xsl:param name="SECOND" />

    <xsl:call-template name="MAKE_ENTRY">
        <xsl:with-param name="BEFORE" select="$SECOND" />
        <xsl:with-param name="AFTER" select="$FIRST" />
    </xsl:call-template>
</xsl:template>


<xsl:template name="GET_FILENAME">
    <xsl:param name="ID" />

    <xsl:value-of select="$WEB_ROOT_ABSOLUTE_FILE_PATH" />
    <xsl:text>/build-</xsl:text>
    <xsl:value-of select="$ID" />
    <xsl:text>/report.xml</xsl:text>
</xsl:template>



<xsl:template name="MAKE_ENTRY" xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
    <xsl:param name="BEFORE" />
    <xsl:param name="AFTER" />

    <xsl:variable name="FAILURES_SINCE_LAST_BUILD">
        <xsl:call-template name="FIND_NEW_FAILURES">
            <xsl:with-param name="BEFORE" select="$BEFORE" />
            <xsl:with-param name="AFTER" select="$AFTER" />
        </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="FIXES_SINCE_LAST_BUILD">
        <xsl:call-template name="FIND_NEW_FIXES">
            <xsl:with-param name="BEFORE" select="$BEFORE" />
            <xsl:with-param name="AFTER" select="$AFTER" />
        </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="PERSISTING_FAILURES">
        <xsl:call-template name="FIND_PERMANENT_FAILURES">
            <xsl:with-param name="BEFORE" select="$BEFORE" />
            <xsl:with-param name="AFTER" select="$AFTER" />
        </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="SUMMARY">
        <xsl:call-template name="MAKE_SUMMARY">
            <xsl:with-param name="REGRESSION_LIST" select="$FAILURES_SINCE_LAST_BUILD" />
            <xsl:with-param name="IMPROVEMENT_LIST" select="$FIXES_SINCE_LAST_BUILD" />
        </xsl:call-template>
    </xsl:variable>

    <entry>
        <title>Build <xsl:value-of select="$AFTER/build/@number" /> (<xsl:value-of select="$SUMMARY" />)</title>
        <link>
            <xsl:attribute name="href">
                <xsl:value-of select="$BASE_URL" />
                <xsl:text>build-</xsl:text>
                <xsl:value-of select="$AFTER/build/@number" />
                <xsl:text>/</xsl:text>
            </xsl:attribute>
        </link>
        <updated><xsl:value-of select="$AFTER/build/buildinfo/@started" /></updated>
        <id>tag:<xsl:value-of select="$RSS_TAG_PREFIX" />,build-diff-<xsl:value-of select="$BEFORE/build/@number" />-<xsl:value-of select="$AFTER/build/@number" /></id>
        <content type="xhtml">
            <xhtml:div xmlns:xhtml="http://www.w3.org/1999/xhtml">
                <xhtml:h1>HelenOS nightly build <xsl:value-of select="$AFTER/build/@number" /> (<xsl:value-of select="$SUMMARY" />)</xhtml:h1>
                <xhtml:h2>Broken since build <xsl:value-of select="$BEFORE/build/@number" /></xhtml:h2>
                <xsl:choose>
                    <xsl:when test="normalize-space($FAILURES_SINCE_LAST_BUILD) = ''">
                        <xhtml:p>No change.</xhtml:p>
                    </xsl:when>
                    <xsl:otherwise>
                        <xhtml:ul>
                            <xsl:call-template name="MAKE_LIST">
                                <xsl:with-param name="ROOT" select="$AFTER" />
                                <xsl:with-param name="LOGS" select="normalize-space($FAILURES_SINCE_LAST_BUILD)" />
                            </xsl:call-template>
                        </xhtml:ul>
                    </xsl:otherwise>
                </xsl:choose>

                <xhtml:h2>Fixed since build <xsl:value-of select="$BEFORE/build/@number" /></xhtml:h2>
                <xsl:choose>
                    <xsl:when test="normalize-space($FIXES_SINCE_LAST_BUILD) = ''">
                        <xhtml:p>No change.</xhtml:p>
                    </xsl:when>
                    <xsl:otherwise>
                        <xhtml:ul>
                            <!--  Remove the link here -->
                            <xsl:call-template name="MAKE_LIST">
                                <xsl:with-param name="ROOT" select="$BEFORE" />
                                <xsl:with-param name="LOGS" select="normalize-space($FIXES_SINCE_LAST_BUILD)" />
                            </xsl:call-template>
                        </xhtml:ul>
                    </xsl:otherwise>
                </xsl:choose>

                <xhtml:h2>Still failing</xhtml:h2>
                <xsl:choose>
                    <xsl:when test="normalize-space($PERSISTING_FAILURES) = ''">
                        <xhtml:p>No other failures.</xhtml:p>
                    </xsl:when>
                    <xsl:otherwise>
                        <xhtml:ul>
                            <!--  Remove the link here -->
                            <xsl:call-template name="MAKE_LIST">
                                <xsl:with-param name="ROOT" select="$AFTER" />
                                <xsl:with-param name="LOGS" select="normalize-space($PERSISTING_FAILURES)" />
                            </xsl:call-template>
                        </xhtml:ul>
                    </xsl:otherwise>
                </xsl:choose>
            </xhtml:div>
        </content>
    </entry>
</xsl:template>

<xsl:template name="FIND_NEW_FAILURES">
    <xsl:param name="BEFORE" />
    <xsl:param name="AFTER" />
    <xsl:for-each select="$AFTER/build/*[@result = 'fail']">
        <xsl:sort />
        <xsl:variable name="AFTER_LOG" select="./@log" />
        <xsl:variable name="BEFORE_NODE" select="$BEFORE/build/*[@log=$AFTER_LOG][1]" />
        <xsl:if test="not($BEFORE_NODE)">
            <xsl:value-of select="$AFTER_LOG" />
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:for-each>
    <xsl:for-each select="$BEFORE/build/*[@result != 'fail']">
        <xsl:sort />
        <xsl:variable name="BEFORE_RESULT" select="./@result" />
        <xsl:variable name="BEFORE_LOG" select="./@log" />
        <xsl:variable name="AFTER_NODE" select="$AFTER/build/*[@log=$BEFORE_LOG][1]" />
        <xsl:variable name="AFTER_RESULT" select="$AFTER_NODE/@result" />
        <xsl:if test="$AFTER_RESULT = 'fail'">
            <xsl:value-of select="$BEFORE_LOG" />
            <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:if test="($AFTER_RESULT = 'skip') and ($BEFORE_RESULT = 'ok')">
            <xsl:value-of select="$BEFORE_LOG" />
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:for-each>
</xsl:template>

<xsl:template name="FIND_NEW_FIXES">
    <xsl:param name="BEFORE" />
    <xsl:param name="AFTER" />
    <xsl:for-each select="$AFTER/build/*[@result = 'ok']">
        <xsl:sort />
        <xsl:variable name="AFTER_RESULT" select="./@result" />
        <xsl:variable name="AFTER_LOG" select="./@log" />
        <xsl:variable name="BEFORE_NODE" select="$BEFORE/build/*[@log=$AFTER_LOG][1]" />
        <xsl:variable name="BEFORE_RESULT" select="$BEFORE_NODE/@result" />
        <xsl:if test="$BEFORE_RESULT = 'fail'">
            <xsl:value-of select="$AFTER_LOG" />
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:for-each>
</xsl:template>

<xsl:template name="FIND_PERMANENT_FAILURES">
    <xsl:param name="BEFORE" />
    <xsl:param name="AFTER" />
    <xsl:for-each select="$BEFORE/build/*[@result != 'ok']">
        <xsl:sort select="name()" />
        <xsl:sort select="@package" />
        <xsl:sort select="@arch" />
        <xsl:sort select="@scenario" />
        <xsl:variable name="BEFORE_RESULT" select="./@result" />
        <xsl:variable name="BEFORE_LOG" select="./@log" />
        <xsl:variable name="AFTER_NODE" select="$AFTER/build/*[@log=$BEFORE_LOG][1]" />
        <xsl:variable name="AFTER_RESULT" select="$AFTER_NODE/@result" />
        <xsl:if test="($AFTER_RESULT != 'ok') and not(($BEFORE_RESULT = 'skip') and ($AFTER_RESULT = 'fail'))">
            <xsl:value-of select="$BEFORE_LOG" />
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:for-each>
</xsl:template>




<xsl:template name="MAKE_LIST">
    <xsl:param name="ROOT" />
    <xsl:param name="LOGS" />

    <xsl:variable name="FIRST">
        <xsl:choose>
            <xsl:when test="substring-before($LOGS, ' ') = ''">
                <xsl:value-of select="$LOGS" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="substring-before($LOGS, ' ')" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:variable name="REMAINING" select="substring-after($LOGS, ' ')" />

    <xsl:variable name="NODE" select="$ROOT/build/*[@log=$FIRST][1]" />

    <xsl:variable name="TEXT">
        <xsl:apply-templates select="$NODE" mode="failure-list" />
    </xsl:variable>

    <xhtml:li>
        <xhtml:a>
            <xsl:attribute name="href">
                <xsl:value-of select="$BASE_URL" />
                <xsl:text>build-</xsl:text>
                <xsl:value-of select="$ROOT/build/@number" />
                <xsl:text>/</xsl:text>
                <xsl:value-of select="$NODE/@log" />
            </xsl:attribute>
            <xsl:value-of select="$TEXT" />
        </xhtml:a>
    </xhtml:li>

    <xsl:if test="$REMAINING != ''" >
        <xsl:call-template name="MAKE_LIST">
            <xsl:with-param name="ROOT" select="$ROOT" />
            <xsl:with-param name="LOGS" select="$REMAINING" />
        </xsl:call-template>
    </xsl:if>
</xsl:template>


<xsl:template match="browsable-sources-global" mode="failure-list">
    <xsl:text>Browsable sources.</xsl:text>
</xsl:template>

<xsl:template match="checkout" mode="failure-list">
    <xsl:text>Checkout of </xsl:text>
    <xsl:value-of select="@repository" />
    <xsl:text>.</xsl:text>
</xsl:template>

<xsl:template match="harbour-build" mode="failure-list">
    <xsl:text>Harbour build of </xsl:text>
    <xsl:value-of select="@package" />
    <xsl:text> for </xsl:text>
    <xsl:value-of select="@arch" />
    <xsl:text>.</xsl:text>
</xsl:template>

<xsl:template match="harbour-fetch" mode="failure-list">
    <xsl:text>Harbour fetch for </xsl:text>
    <xsl:value-of select="@package" />
    <xsl:text>.</xsl:text>
</xsl:template>

<xsl:template match="helenos-build" mode="failure-list">
    <xsl:text>HelenOS build for </xsl:text>
     <xsl:value-of select="@arch" />
    <xsl:text>.</xsl:text>
</xsl:template>

<xsl:template match="helenos-extra-build" mode="failure-list">
    <xsl:text>HelenOS extra build with </xsl:text>
    <xsl:value-of select="@harbours" />
    <xsl:text> for </xsl:text>
     <xsl:value-of select="@arch" />
    <xsl:text>.</xsl:text>
</xsl:template>

<xsl:template match="sycek-style-check" mode="failure-list">
    <xsl:text>Sycek C style check.</xsl:text>
</xsl:template>

<xsl:template match="test" mode="failure-list">
    <xsl:text>Automated test </xsl:text>
    <xsl:value-of select="@scenario" />
    <xsl:text> on </xsl:text>
    <xsl:value-of select="@arch" />
    <xsl:text>.</xsl:text>
</xsl:template>

<xsl:template match="tool-build" mode="failure-list">
    <xsl:text>Build of </xsl:text>
    <xsl:value-of select="@tool" />
    <xsl:text> tool.</xsl:text>
</xsl:template>


<xsl:template match="*" mode="failure-list">
    <xsl:value-of select="name()" />
    <xsl:text>.</xsl:text>
</xsl:template>


<xsl:template name="MAKE_SUMMARY">
    <xsl:param name="REGRESSION_LIST" select="''" />
    <xsl:param name="IMPROVEMENT_LIST" select="''" />

    <xsl:variable name="REGRESSION_COUNT">
        <xsl:call-template name="COUNT_ITEMS">
             <xsl:with-param name="LIST" select="normalize-space($REGRESSION_LIST)" />
        </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="IMPROVEMENT_COUNT">
        <xsl:call-template name="COUNT_ITEMS">
             <xsl:with-param name="LIST" select="normalize-space($IMPROVEMENT_LIST)" />
        </xsl:call-template>
    </xsl:variable>

    <!--
    <xsl:text>[</xsl:text>
    <xsl:value-of select="$REGRESSION_COUNT" />
    <xsl:text>:</xsl:text>
    <xsl:value-of select="$IMPROVEMENT_COUNT" />
    <xsl:text>]</xsl:text>
    -->

    <xsl:variable name="REGRESSION_TEXT">
        <xsl:choose>
            <xsl:when test="$REGRESSION_COUNT = 1">
                <xsl:text>1 regression</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$REGRESSION_COUNT" />
                <xsl:text> regressions</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="IMPROVEMENT_TEXT">
        <xsl:choose>
            <xsl:when test="$IMPROVEMENT_COUNT = 1">
                <xsl:text>1 fix</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$IMPROVEMENT_COUNT" />
                <xsl:text> fixes</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

       <xsl:choose>
           <xsl:when test="$REGRESSION_COUNT + $IMPROVEMENT_COUNT = 0">
               <xsl:text>no change</xsl:text>
           </xsl:when>
           <xsl:when test="$REGRESSION_COUNT = 0">
               <xsl:value-of select="$IMPROVEMENT_TEXT" />
           </xsl:when>
           <xsl:when test="$IMPROVEMENT_COUNT = 0">
               <xsl:value-of select="$REGRESSION_TEXT" />
           </xsl:when>
           <xsl:otherwise>
               <xsl:value-of select="$REGRESSION_TEXT" />
               <xsl:text>, </xsl:text>
               <xsl:value-of select="$IMPROVEMENT_TEXT" />
           </xsl:otherwise>
       </xsl:choose>
</xsl:template>

<xsl:template name="COUNT_ITEMS">
    <xsl:param name="LIST" select="''" />

    <xsl:variable name="FIRST">
        <xsl:choose>
            <xsl:when test="substring-before($LIST, ' ') = ''">
                <xsl:value-of select="$LIST" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="substring-before($LIST, ' ')" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="REMAINING" select="substring-after($LIST, ' ')" />

    <xsl:variable name="REMAINING_COUNT">
        <xsl:choose>
            <xsl:when test="$REMAINING = ''">0</xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="COUNT_ITEMS">
                    <xsl:with-param name="LIST" select="$REMAINING" />
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="RESULT">
        <xsl:choose>
            <xsl:when test="$FIRST = ''">0</xsl:when>
            <xsl:otherwise><xsl:value-of select="1 + $REMAINING_COUNT" /></xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:value-of select="$RESULT" />
</xsl:template>

</xsl:stylesheet>

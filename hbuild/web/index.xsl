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

<xsl:output method="html" indent="yes" />

<xsl:param name="PREVIOUS_BUILDS" select="''" />
<xsl:param name="LAST_BUILD" select="''" />

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
            <xsl:text>HelenOS CI</xsl:text>
        </xsl:with-param>
        <xsl:with-param name="EXTRA_HEAD">
        </xsl:with-param>
        <xsl:with-param name="BODY">
            <div id="centeredd">
        
        <h1 id="top-of-page">HelenOS continuous integration testing</h1>
        <div id="summary">
            <h2>Last build</h2>
            <p class="action buttonset">
                <a href="build-{$LAST_BUILD}/index.html">See details of this build.</a>
            </p>
            <xsl:apply-templates select="." mode="html-summary-table" />
        </div>
        
        <xsl:if test="normalize-space($PREVIOUS_BUILDS) != ''">
        <h2>Previous builds</h2>
        <ul class="previous-builds buttonset">
        <xsl:call-template name="MAKE_LINKS_TO_PREVIOUS_BUILDS">
            <xsl:with-param name="BUILDS" select="normalize-space($PREVIOUS_BUILDS)" />
        </xsl:call-template>
        </ul>
        </xsl:if>
        </div>
        </xsl:with-param>
        
    </xsl:call-template>
</xsl:template>

<xsl:template name="MAKE_LINKS_TO_PREVIOUS_BUILDS">
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
    
    <li>
        <a href="build-{$FIRST}/index.html">Build <xsl:value-of select="$FIRST" /></a>
    </li>
    <xsl:if test="$REMAINING != ''" >
        <xsl:call-template name="MAKE_LINKS_TO_PREVIOUS_BUILDS">
            <xsl:with-param name="BUILDS" select="$REMAINING" />
        </xsl:call-template>
    </xsl:if>
</xsl:template>

</xsl:stylesheet>

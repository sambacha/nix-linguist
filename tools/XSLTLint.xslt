<?xml version="1.0" encoding="utf-8" ?>
<!--
	## XSLTLint.xslt
	
	Tests an XSLT file for some common (and frankly, embarrassing) errors.
-->
<!DOCTYPE xsl:stylesheet [
	<!ENTITY LF "&#x0a;">
	<!ENTITY TAB "&#x09;">
	<!ENTITY KEY_BEGIN "'key('">
]>
<xsl:stylesheet
	version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:make="http://exslt.org/common"
	exclude-result-prefixes="make"
>

	<xsl:output method="text" indent="no" omit-xml-declaration="yes" />

	<!-- Indexes -->
	<xsl:key name="namedTemplatesIndex" match="xsl:template"             use="@name" />
	<xsl:key name="matchTemplatesIndex" match="xsl:template"             use="@match" />
	<xsl:key name="modedTemplatesIndex" match="xsl:template"             use="@mode" />
	<xsl:key name="variableNamesIndex"  match="xsl:variable | xsl:param" use="@name" />
	<xsl:key name="keyNamesIndex"       match="xsl:key"                  use="@name" />

	<!-- Global variables -->
	<xsl:variable name="apos">&apos;</xsl:variable>
	<xsl:variable name="quot">&quot;</xsl:variable>
	<xsl:variable name="LF" xml:space="preserve">&LF;&LF;</xsl:variable>

	<xsl:variable name="ns-prefixes-RTF">
		<xsl:for-each select="/*/namespace::*">
			<ns prefix="{local-name()}" url="{.}" />
		</xsl:for-each>
	</xsl:variable>
	<xsl:variable name="ns-prefixes" select="make:node-set($ns-prefixes-RTF)/ns" />
	<xsl:variable name="no-go-chars" select="concat($apos, $quot, '/(;)=&amp;&lt;&gt;$#€%!?+^`´@*\')" />
	
	<xsl:variable name="selectAttrs" select="//xsl:*/@select" />
	<xsl:variable name="testAttrs" select="//xsl:*/@test" />
	<xsl:variable name="exprAttrs" select="$selectAttrs | $testAttrs" />
	
	<!-- Grab any includes/imports -->
	<xsl:variable name="includes" select="/xsl:stylesheet/*[self::xsl:include or self::xsl:import]" />
	
	<xsl:template match="/">
		<!--
		Start by testing some special cases
		-->
			
		<!-- Undeclared namespaces -->
		<xsl:apply-templates select="$selectAttrs[substring-before(., ':')][not(substring-before(., '::'))]" mode="undeclared-ns-prefix" />

		<!-- Grab a reference inside this doc -->
		<xsl:variable name="excluded-prefixes" select="xsl:stylesheet/@exclude-result-prefixes" />
		
		<!-- Missing prefixes in `exclude-result-prefixes` attribute -->
		<xsl:for-each select="$ns-prefixes">
			<xsl:variable name="prefix" select="@prefix" />
			<xsl:if test="not(contains('xml xsl', $prefix)) and not(contains($excluded-prefixes, $prefix))">
				<xsl:call-template name="error">
					<xsl:with-param name="message" select="concat('Prefix ', $quot, $prefix, ':', $quot, ' is not excluded (so will be copied to result document).')" />
				</xsl:call-template>
			</xsl:if>
		</xsl:for-each>
		
		<!-- Undeclared variables/params -->
		<xsl:apply-templates select="$exprAttrs[starts-with(., '$')]" mode="undeclared-variable" />
		
		<!-- Undeclared keys -->
		<xsl:apply-templates select="$exprAttrs[contains(., &KEY_BEGIN;)]" mode="undeclared-key" />
		
		<!-- Illegal AVTs -->
		<xsl:apply-templates select="$selectAttrs[contains(., '{') and contains(., '}')]" mode="illegal-avt" />
		
		<!-- Now process the various elements in the stylesheet -->
		<xsl:apply-templates select="*" />
		
	</xsl:template>
	
	<xsl:template match="*">
		<xsl:apply-templates select="*" />
	</xsl:template>
	
	<!--
	Checks for variable declarations including the dollar-sign (it happens)
	-->
	<xsl:template match="xsl:variable[starts-with(@name, '$')] | xsl:param[starts-with(@name, '$')]">
		<xsl:call-template name="error">
			<xsl:with-param name="message" select="concat('A variable name (', @name, ') was declared starting with a $ symbol.')" />
		</xsl:call-template>
	</xsl:template>

	<!--
	Test if we're accidentally calling a template that doesn't exist.
	It may actually be that it's defined as a match template instead.
	Or it could actually exist in an included/imported file.
	-->
	<xsl:template match="xsl:call-template">
		<xsl:variable name="template" select="@name" />

		<xsl:if test="not(key('namedTemplatesIndex', $template))">
			<xsl:variable name="message" select="concat('No template named &quot;', $template, '&quot; exists, yet it', $apos, 's being called somewhere. ')" />
			<xsl:choose>
				<xsl:when test="$includes">
					<xsl:if test="not(document($includes/@href, /)//xsl:template[@name = $template])">
						<xsl:call-template name="error">
							<xsl:with-param name="message" select="$message" />
						</xsl:call-template>
					</xsl:if>
				</xsl:when>
				<xsl:otherwise>
					<xsl:call-template name="error">
						<xsl:with-param name="message" select="$message" />
					</xsl:call-template>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
		
		<xsl:if test="key('matchTemplatesIndex', $template)">
			<xsl:call-template name="error">
				<xsl:with-param name="message" select="'There is however, a *match template* defined with this name, so looks like a #snippetfail'" />
				<xsl:with-param name="linefeed" select="false()" />
			</xsl:call-template>
		</xsl:if>
		
		<!-- Check for misplaced `<xsl:param>` (where it should have been `<xsl:with-param>`) -->
		<xsl:if test="xsl:param">
			<xsl:call-template name="error">
				<xsl:with-param name="message" select="concat('A call to &quot;', $template, '&quot; contains misplaced `&lt;xsl:param&gt;` (you probably mean `&lt;xsl:with-param&gt;`).')" />
			</xsl:call-template>
		</xsl:if>
	</xsl:template>
	
	<!--
	Test if we accidentally forgot to add a mode to a template
	-->
	<xsl:template match="xsl:apply-templates">
		<xsl:variable name="mode" select="@mode" />
		
		<xsl:if test="normalize-space($mode) and not(key('modedTemplatesIndex', $mode))">
			<xsl:variable name="message" select="concat('An &lt;xsl:apply-templates /&gt; instruction use the mode ', $apos, $mode, $apos, ' but no templates are defined in that mode. Did you forget to add it?')" />
			<xsl:choose>
				<xsl:when test="$includes">
					<xsl:if test="not(document($includes/@href, /)//xsl:template[@mode = $mode])">
						<xsl:call-template name="error">
							<xsl:with-param name="message" select="$message" />
						</xsl:call-template>
					</xsl:if>
				</xsl:when>
				<xsl:otherwise>
					<xsl:call-template name="error">
						<xsl:with-param name="message" select="$message" />
					</xsl:call-template>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>
	
	<!--
	Check for namespace-prefixes that haven't been declared
	-->
	<xsl:template match="@select" mode="undeclared-ns-prefix">
		<xsl:variable name="prefix" select="substring-before(., ':')" />
		
		<!--
		Ideally, this should obviously be "properly" parsed, but we can eliminate a lot of false positives
		just by doing a little filtering - throw away all characters that shouldn't be used in a prefix
		and check if the string is still (probably) the same... 
		-->
		<xsl:if test="string-length($prefix) = string-length(translate($prefix, $no-go-chars, ''))">
			<!-- Go through the declared prefixes to find a match -->
			<xsl:if test="not($ns-prefixes[@prefix = $prefix])">
				<xsl:call-template name="error">
					<xsl:with-param name="message" select="concat('An undeclared namespace prefix (', $prefix, ':) is being used.')" />
				</xsl:call-template>
			</xsl:if>
		</xsl:if>
		
	</xsl:template>
	
	<!--
	Check for undeclared variables
	-->
	<xsl:template match="@select | @test" mode="undeclared-variable">
		<!-- Simplest scenario: `<xsl:value-of select="$variable" />` -->
		<xsl:if test="starts-with(., '$') and string-length(substring-after(., '$')) = string-length(translate(., '$/:[]()', ''))">
			<xsl:if test="not(key('variableNamesIndex', substring-after(., '$')))">
				<xsl:call-template name="error">
					<xsl:with-param name="message" select="concat('Variable/parameter ', ., ' is undeclared.')" />
				</xsl:call-template>
			</xsl:if>
		</xsl:if>
	</xsl:template>
	
	<!--
	Check for missing `xsl:key` declaration
	-->
	<xsl:template match="@select | @test" mode="undeclared-key">
		<xsl:variable name="keyName" select="substring-before(substring(substring-after(., &KEY_BEGIN;), 2), $apos)" />
		<xsl:variable name="message" select="concat('A `key()` function used an undeclared key name (', $keyName, ').')" />
		<xsl:if test="not(key('keyNamesIndex', $keyName))">
			<xsl:choose>
				<xsl:when test="$includes">
					<xsl:if test="not(document($includes/@href, /)//xsl:key[@name = $keyName])">
						<xsl:call-template name="error">
							<xsl:with-param name="message" select="$message" />
						</xsl:call-template>
					</xsl:if>
				</xsl:when>
				<xsl:otherwise>
					<xsl:call-template name="error">
						<xsl:with-param name="message" select="$message" />
					</xsl:call-template>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>

	<xsl:template match="@select" mode="illegal-avt">
		<xsl:call-template name="error">
			<xsl:with-param name="message" select="concat('An AVT (Attribute Value Template) was used in a `@select` attribute (', $quot, ., $quot, ').')" />
		</xsl:call-template>
	</xsl:template>
	
	<!--
	Output template for generating the error messages
	 -->
	<xsl:template name="error">
		<xsl:param name="message" />
		<xsl:param name="linefeed" select="true()" />
		<xsl:if test="$linefeed"><xsl:value-of select="$LF" /></xsl:if>
		<xsl:value-of select="$message" />
	</xsl:template>
	
</xsl:stylesheet>

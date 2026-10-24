\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{iarticle}[2026/09/22 v1.1 Article Class]

\RequirePackage{etoolbox}
\newbool{chinese}
\DeclareOption{chinese}{\booltrue{chinese}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax

\PassOptionsToPackage{dvipsnames}{xcolor}

\LoadClass{article}

\RequirePackage{amsmath}
\RequirePackage{amssymb}
\RequirePackage{amsthm}
\RequirePackage{array}
\RequirePackage{booktabs}
\RequirePackage{caption}
\RequirePackage{enumitem}
\RequirePackage{esint}
\RequirePackage{fancyhdr}
\RequirePackage{float}
\RequirePackage{fontspec}
\RequirePackage{geometry}
\RequirePackage{graphicx}
\RequirePackage{import}
\RequirePackage{lastpage}
% \RequirePackage{mathtools}
\RequirePackage{microtype}
\RequirePackage{multicol}
\RequirePackage{multirow}
\RequirePackage{siunitx}
% Load physics after siunitx so that \qty keeps its physics semantics.
\RequirePackage{physics}
% The shared command name is resolved intentionally above, so silence
% siunitx's informational package-coexistence warning.
\ExplSyntaxOn
\msg_redirect_name:nnn { siunitx } { physics-pkg } { none }
\ExplSyntaxOff
\RequirePackage{tabularx}
\RequirePackage{tasks}
\RequirePackage{tcolorbox}
\RequirePackage{ulem}
\RequirePackage{xcolor}
\RequirePackage{xkeyval}

% 后添加命令
\RequirePackage[lighttt]{lmodern}
\RequirePackage[version=4]{mhchem}
\RequirePackage{wrapfig}
\RequirePackage{extarrows}
\RequirePackage{floatflt}
\RequirePackage{subcaption}
\RequirePackage{bm}
\RequirePackage[math-style=ISO, bold-style=ISO]{unicode-math}

\setmainfont[
  Extension = .otf,
  UprightFont = *-Regular,
  BoldFont = *-Bold,
  ItalicFont = *-Italic,
  BoldItalicFont = *-BoldItalic,
]{XITS}

\setmathfont[
  Extension = .otf,
  BoldFont = XITSMath-Bold,
]{XITSMath-Regular}

\ifbool{chinese}{\RequirePackage[UTF8]{ctex}}{}

\ifbool{chinese}{
  \IfFontExistsTF{SimSun}{
    \IfFontExistsTF{SimHei}{
      \setCJKmainfont{SimSun}[BoldFont=SimHei]
    }{}
  }{}
}{}
% Hyperlinks should be initialised after the document's formatting packages;
% cleveref must follow hyperref.
\RequirePackage{hyperref}
\RequirePackage{cleveref}

% Enable GB/T 7714--2025 only when a document actually has a bibliography.
% This keeps documents without references on the original compilation path.
% Use in the preamble: \gbbibliography{references.bib}
\newbool{gbbibliographyloaded}
\DeclareDocumentCommand{\gbbibliography}{m}{%
  \IfFileExists{#1}{}{%
    \ClassError{iarticle}{Bibliography database '#1' not found}%
      {Check the path passed to \string\gbbibliography.}%
  }%
  \ifbool{gbbibliographyloaded}{%
    \addbibresource{#1}%
  }{%
    \IfFileExists{gb7714-2025.bbx}{}{%
      \ClassError{iarticle}{GB/T 7714--2025 bibliography style not found}%
        {Keep gb7714-2025.bbx and gb7714-2025.cbx beside iarticle.cls,^^J%
         or install a current biblatex-gb7714-2015 package.}%
    }%
    \IfFileExists{gb7714-2025.cbx}{}{%
      \ClassError{iarticle}{GB/T 7714--2025 citation style not found}%
        {Keep gb7714-2025.bbx and gb7714-2025.cbx beside iarticle.cls,^^J%
         or install a current biblatex-gb7714-2015 package.}%
    }%
    \RequirePackage[
      backend = biber,
      style   = gb7714-2025,
      sorting = none
    ]{biblatex}%
    \booltrue{gbbibliographyloaded}%
    \addbibresource{#1}%
  }%
}

\DeclareDocumentCommand{\ilatex}{}{\href{https://github.com/liblaf/ilatex}{i\LaTeX}}

\floatplacement{figure}{H}
\floatplacement{table}{H}
\geometry{
  hmargin = 20mm,
  paper   = a4paper,
  vmargin = 25mm,
}
\hypersetup{
  colorlinks = true,
  % https://tex.stackexchange.com/a/525984
  linkcolor       = BrickRed,
  citecolor       = Green,
  filecolor       = Mulberry,
  urlcolor        = NavyBlue,
  menucolor       = BrickRed,
  runcolor        = Mulberry,
  linkbordercolor = BrickRed,
  citebordercolor = Green,
  filebordercolor = Mulberry,
  urlbordercolor  = NavyBlue,
  menubordercolor = BrickRed,
  runbordercolor  = Mulberry,
}
\linespread{1.3}
\setlength{\columnsep}{10mm}
\renewcommand{\tabularxcolumn}[1]{>{\centering\arraybackslash}m{#1}}

\tcbuselibrary{breakable}
\tcbuselibrary{listings}
\tcbuselibrary{skins}
\tcbuselibrary{theorems}
\tcbuselibrary{xparse}
\tcbset{
  breakable,
  colback  = blue!10!white,
  colframe = blue!80!white,
  enhanced,
  fonttitle = \bfseries,
}

\DeclareDocumentCommand{\course}{m}{\csdef{@course}{#1}}
\DeclareDocumentCommand{\id}{m}{\csdef{@id}{#1}}
\DeclareDocumentCommand{\name}{m}{\csdef{@name}{#1}}
\DeclareDocumentCommand{\phnum}{m}{\csdef{@phnum}{#1}}

\DeclareDocumentCommand{\thecourse}{}{\csuse{@course}}
\DeclareDocumentCommand{\theid}{}{\csuse{@id}}
\DeclareDocumentCommand{\thename}{}{\csuse{@name}}
\DeclareDocumentCommand{\thephnum}{}{\csuse{@phnum}}
\author{
  \thename \quad \theid \quad 实验日期：\@date \quad \thephnum
}

\ifbool{chinese}{
  \pagestyle{fancy}
  \fancyhead[L]{\small\textsl{\rightmark}}
  \fancyhead[R]{\small\textsl{\leftmark}}
  \fancyfoot[C]{第 \thepage{} 页，共 \,\pageref{LastPage}\, 页}
}{
  \pagestyle{fancy}
  \fancyhead[L]{\small\textsl{\rightmark}}
  \fancyhead[R]{\small\textsl{\leftmark}}
  \fancyfoot[C]{Page \thepage{} of \,\pageref{LastPage}}
}

\fancypagestyle{titlepage}{
  \fancyhead[L]{\small \thecourse}
  \fancyhead[C]{}
  \fancyhead[R]{\small \@date}
  \renewcommand{\headrulewidth}{0.4pt}
}

\DeclareDocumentCommand{\maketitle}{}{
  \thispagestyle{titlepage}
  \begin{center}
    { \LARGE \@title }
    \par \vspace{0.5em}
    \normalsize
    \begin{tabular}[t]{c}
      \csuse{@author}
    \end{tabular}
  \end{center}
}

\sisetup{
  uncertainty-mode = separate,
}
\ifbool{chinese}{
  \sisetup{
    list-final-separator = 和 \,,
    list-pair-separator  = 和 \,,
    per-mode             = symbol,
    range-phrase         = \,\text{--}\,,
  }
}{}

\ifbool{chinese}{
  \DeclareDocumentCommand{\keywordsname}{}{关键词}
}{
  \DeclareDocumentCommand{\keywordsname}{}{Keywords}
}
\DeclareDocumentCommand{\keywords}{m}{
  \par \vspace{0.5em}
  \textbf{\keywordsname :} #1
}

\define@cmdkey{image}{caption}[]{}
\define@cmdkey{image}{label}[]{}
\define@cmdkey{image}{placement}[htbp]{}
\DeclareDocumentCommand{\image}{O{} O{} m}{
  \begingroup
  \presetkeys{image}{
    caption = {},
    label = {},
    placement = htbp,
  }{}
  \setkeys{image}{#1}
  \edef\image@beginfigure{\noexpand\begin{figure}[\cmdKV@image@placement]}
  \image@beginfigure
    \centering
    \ifstrempty{#2}{
      \includegraphics[height = 0.3\linewidth]{#3}
    }{
      \includegraphics[#2]{#3}
    }
    \ifdefempty{\cmdKV@image@caption}{
      \ifdefempty{\cmdKV@image@label}{}{
        \ClassWarning{iarticle}{Image label '\cmdKV@image@label' ignored because the caption is empty}
      }
    }{
      \caption{\cmdKV@image@caption}
      \ifdefempty{\cmdKV@image@label}{}{
        \label{fig:\cmdKV@image@label}
      }
    }
  \end{figure}
  \endgroup
}

\graphicspath{{assets/}}
\id{2026310543}
\phnum{}
\ifbool{chinese}{
  \course{深度学习及其应用技术}
  \name{邓康}
}{
  \course{Deep Learning and Its Application Technology}
  \name{Deng Kang}
}

% 罗马数字
\newcommand{\roma}[1]{{\rm \uppercase\expandafter{\romannumeral #1}}}
% Upright differentials are provided by physics as \dd; keep LaTeX's
% built-in \d accent untouched.

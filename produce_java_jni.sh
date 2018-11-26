g++ -x c++ -std=c++11 - << EOF

#include <fstream>
#include <string>
#include <iostream>
#include <vector>

#include <string.h>
#include <time.h>

/*
jbyte* arr = env->GetByteArrayElements(data, NULL);
jint length = env->GetArrayLength(data);
env->ReleaseByteArrayElements(data, arr, 0);
*/

using std::ifstream;
using std::ofstream;
using std::ios_base;
using std::string;
using std::cout;
using std::endl;
using std::vector;

static const string className = R"==(JNIEngine)==";

#define NEW_LINE out.write("\n", 1);
#define NATIVE_PREFIX "native"

string getname(string& str)
{
    auto func_end = str.find_first_of("(") - 1;
    auto func_start = str.find_last_of(" ", func_end) + 1;

    return string(str, func_start, func_end - func_start + 1);
}

string& replace_all_distinct(string& str, const string& old_value, const string& new_value)
{
    for(string::size_type pos(0); pos!=string::npos; pos += new_value.length())
	{
        if((pos = str.find(old_value, pos)) !=string::npos)
            str.replace(pos, old_value.length(), new_value);
        else
		    break;
    }

    return str;
}

string getSign(string input)
{
    string  str = input;

    replace_all_distinct(str, "long ", "");
    replace_all_distinct(str, "int ", "");
    replace_all_distinct(str, "float ", "");
    replace_all_distinct(str, "double ", "");
    replace_all_distinct(str, "byte[] ", "");
    replace_all_distinct(str, "int[] ", "");

    return str;
}

string gettime(void)
{
    time_t timetTime;
    struct tm *pTmTime;
    char   szTime[1000] = {0};

    timetTime = time(NULL);

    pTmTime = localtime(&timetTime);
    snprintf(szTime, sizeof(szTime)-1,
     "/********************************************************************\nauto created by chijilyb's autojnitool: %d-%02d-%02d %02d:%02d:%02d\n********************************************************************/\n\n",
        pTmTime->tm_year+1900,
        pTmTime->tm_mon+1,
        pTmTime->tm_mday,
        pTmTime->tm_hour,
        pTmTime->tm_min,
        pTmTime->tm_sec);

    return szTime;
}

string getSignByString(string& s)
{
    // int[] should be ahead of int
    if(s.find("byte[]") != string::npos) return "[B";
    if(s.find("int[]") != string::npos) return "[I";
    if(s.find("long") != string::npos) return "J";
    if(s.find("int") != string::npos) return "I";
    if(s.find("float") != string::npos) return "F";
    if(s.find("double") != string::npos) return "D";

    return "X";
}

string getSignByArgu(vector<string>& vec)
{
    string s;
    for(auto i:vec)
    {
        s += getSignByString(i);
    }

    return s;
}

int main(int argc, char**)
{
    ofstream out((className+".java").c_str(), ios_base::binary);

    string time = gettime();
    out.write(time.c_str(), strlen(time.c_str()));

    const auto pkgname = R"==(package com.arcsoft.)==" + className + ";\n\n\n";

    out.write(pkgname.c_str(), strlen(pkgname.c_str()));

    const auto prehead = R"==(public class )==" + className + "\n{\n";

    out.write(prehead.c_str(), strlen(prehead.c_str()));

    NEW_LINE


    ifstream in("java.txt", ios_base::binary);
    string str;
    string prefix("\tpublic ");

    vector<string> funcionvec;
    vector<string> funcvec;

    while(getline(in, str))
    {
        funcionvec.push_back(str);

        string functionName = getname(str);
        funcvec.push_back(functionName);

        auto functionSign = getSign(str.substr(str.find(functionName)+functionName.size()));

        string function = prefix + str.substr(0, str.size() - 1) + "\n\t{\n\t\treturn " + NATIVE_PREFIX +
        functionName + functionSign + "\n\t}\n\n";

        out.write(function.c_str(), strlen(function.c_str()));
    }

    for(auto v:funcionvec)
    {
        string function = v;
        replace_all_distinct(function, "long ", string("long ") + NATIVE_PREFIX);
        replace_all_distinct(function, "int ", string("int ") + NATIVE_PREFIX);

        string str = string("\tprivate native ") + function + "\n";

        out.write(str.c_str(), strlen(str.c_str()));
    }

    out.write("}", 1);

    out.close();

    ofstream out2((className+"_jni.cpp").c_str(), ios_base::binary);
    string time2 = gettime();
    out2.write(time2.c_str(), strlen(time2.c_str()));

    string jni_header("#include <jni.h>\n\n");
    out2.write(jni_header.c_str(), jni_header.size());

    for(auto v:funcionvec)
    {
        string function = v;
        replace_all_distinct(function, "long ", string("jlong "));
        replace_all_distinct(function, "int ", string("jint "));
        replace_all_distinct(function, "float ", string("jfloat "));
        replace_all_distinct(function, "double ", string("jdouble "));
        replace_all_distinct(function, "int[] ", string("jintArray "));
        replace_all_distinct(function, "byte[] ", string("jbyteArray "));

        string str = string("JNIEXPORT ") + function.substr(0, function.size()-1) + "\n{\n\treturn 0;\n}\n\n";

        replace_all_distinct(str, "JNIEXPORT jint ", string("JNIEXPORT jint native"));
        replace_all_distinct(str, "JNIEXPORT jlong ", string("JNIEXPORT jlong native"));
        replace_all_distinct(str, "(", string("(JNIEnv* env, jobject obj, "));

        out2.write(str.c_str(), str.size());
    }

    const static auto Java_class = string("const char* const Java_class = \"com/arcsoft/") + className + "/" + className + "\";\n\n";

    out2.write(Java_class.c_str(), Java_class.size());

    string method = string("static JNINativeMethod gMethods[] = {\n");

	vector<string> signvec;
	{
		ifstream in("java.txt", ios_base::binary);

		string str;

		while(getline(in, str))
		{
			auto start_arentheses = str.find("(") + 1;
			auto end_arentheses = str.find(")") - 1;
			string whole = string(str, start_arentheses, end_arentheses - start_arentheses + 1);
			whole = whole.substr(0, whole.find_last_of(" "));

			auto end_arg = string::npos;

			auto temp = whole;

			while((end_arg = whole.find_last_of(",", end_arg)) != string::npos)
			{
				auto start_arg = whole.find_last_of(" ", end_arg);

				replace_all_distinct(temp, string(whole, start_arg, end_arg - start_arg + 1), "");

				--end_arg;
			}

			auto laststart = 0;
			auto start = 0;
			vector<string> v;
			while((start  = temp.find(" ", laststart)) != string::npos)
			{
				v.push_back(temp.substr(laststart, start - laststart + 1));
				laststart = start + 1;
			}

			v.push_back(temp.substr((laststart > 1)?(laststart - 1):laststart));

			string sign = getSignByArgu(v);

			signvec.push_back(sign);

		}
	}

	auto i = 0;
    for(auto v:funcvec)
    {
        method = method + "\t{\"" + NATIVE_PREFIX + v + R"==(", "()==" + signvec[i++] + R"==()I", (void*))==" + NATIVE_PREFIX + v + "},\n";
    }
    method += "};";

    out2.write(method.c_str(), method.size());


    string end = R"==(

static int RegisterNativeMethods(JNIEnv* env, const char* className,
        JNINativeMethod* gMethods, int numMethods)
{
    jclass clazz;
    clazz = env->FindClass(className);
    if(clazz == MNull)
    {
        return JNI_FALSE;
    }

    if(env->RegisterNatives(clazz, gMethods, numMethods) < 0)
    {
        return JNI_FALSE;
    }

    return JNI_TRUE;
}

static void UnregisterNativeMethods(JNIEnv* env, const char* className)
{
    jclass clazz;
    clazz = env->FindClass(className);

    if(clazz == MNull)
        return;

    if(MNull != env)
    {
        env->UnregisterNatives(clazz);
    }
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved)
{
    JNIEnv* env = NULL;

    if(vm->GetEnv((void**) &env, JNI_VERSION_1_4) != JNI_OK)
    {
        return -1;
    }

    jint ret = RegisterNativeMethods(env, Java_class, gMethods,
            sizeof(gMethods) / sizeof(gMethods[0]));
    if(ret != JNI_TRUE)
    {
        return -1;
    }

    return JNI_VERSION_1_4;
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM* vm, void* reserved)
{
    JNIEnv* env = MNull;
    if(vm->GetEnv((void**) &env, JNI_VERSION_1_4) != JNI_OK)
        return;

    UnregisterNativeMethods(env, Java_class);
})==";

    out2.write(end.c_str(), end.size());

    return 0;
}

EOF

./a.out

rm a.out

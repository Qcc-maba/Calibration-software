using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Reflection;
using System.Data.Common;

namespace Maba.DAL.BaseDAL.Reflection
{
    [AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
    public class PropertyAssignerAttribute : Attribute, IPropertyAssigner
    {
        #region properties

        public string DBColumnName { get; set; }

        /// <summary>
        /// Used only as custom assigner and as attribute
        /// </summary>
        public string CustomPropertyName { get; set; }

        /// <summary>
        /// Should be delegate as CustomValueConverter
        /// </summary>
        public string TypeConvertFunctionName { get; set; }

        public delegate object ConvertorDelegate(DbDataReader reader, bool b, int index);
        public ConvertorDelegate CustomValueConverter { get; set; }

        public bool HasConvertor
        {
            get
            {
                return CustomValueConverter != null || !String.IsNullOrEmpty(TypeConvertFunctionName);
            }
        }

        internal MethodInfo ConvertMethodInfo { get; private set; }
        internal System.Reflection.PropertyInfo Property { get; set; }
        internal int ColumnIndex { get; set; }

        #endregion

        #region ctor

        public PropertyAssignerAttribute()
        {

        }

        public PropertyAssignerAttribute(string ColumnName, string customPropertyName)
            : base()
        {
            DBColumnName = ColumnName;
            CustomPropertyName = customPropertyName;
        }

        public PropertyAssignerAttribute(string ColumnName, string customPropertyName, string ColTypeConvert)
            : this(ColumnName, customPropertyName)
        {
            TypeConvertFunctionName = ColTypeConvert;
        }

        #endregion

        #region internal methods

        internal void GetConvertFunction<T>()
        {
            if (String.IsNullOrEmpty(TypeConvertFunctionName))
                return;

            ConvertMethodInfo = typeof(T).GetMethod(TypeConvertFunctionName, BindingFlags.Static | BindingFlags.Public);
        }

        internal void Assign(DbDataReader dbReader, object o)
        {
            if (CustomValueConverter != null)
            {
                Property.SetValue(o, CustomValueConverter(dbReader, dbReader.IsDBNull(ColumnIndex), ColumnIndex), null);
            }
            else if (ConvertMethodInfo != null)
            {
                Property.SetValue(o, ConvertMethodInfo.Invoke(o, new object[] { dbReader.IsDBNull(ColumnIndex), dbReader.GetValue(ColumnIndex) }), null);
            }
            else
            {
                Property.SetValue(o, dbReader.IsDBNull(ColumnIndex) ? null : dbReader.GetValue(ColumnIndex), null);
            }
        }

        #endregion
    }
}
